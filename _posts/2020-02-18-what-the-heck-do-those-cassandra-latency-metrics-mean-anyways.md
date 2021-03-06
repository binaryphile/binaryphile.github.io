---
layout: post
title: "What the Heck do those Cassandra Latency Metrics Mean, Anyways?"
date: 2020-02-18 14:15 UTC
categories: [ metrics, cassandra ]
---

I recently looked at a Datadog graph of Cassandra client write latencies
and realized I had no idea what the words on it actually meant. I spent
quite some time walking through the Cassandra code to figure it out.
Here are the bullet points from that exploration.

To set the stage, I'm dealing with a Cassandra 2.1.13 environment. Quite
a bit has changed with metrics in Cassandra since then, as that version
is several years old and the team behind Cassandra has actively been
working on metrics during that time. That makes the story slightly
harder to untangle since you have to go to the 2.1.13 timeframe for the
correct answers. Fortunately the git history on these projects is
helpful in that regard.

### TL;DR

In Cassandra 2.1.13, client request read and write metrics are tracked
by both the [Dropwizard metrics] library as well as custom Cassandra
code written outside the Dropwizard code.

The Dropwizard metrics are exposed via Dropwizard's own MBean
implementation underneath the **org.apache.cassandra.metrics** bean. For
example, the client request write latency metrics are accessed under
**org.apache.cassandra.metrics:type=ClientRequest,scope=Write,name=Latency,Attribute=xxx**.
This is the data being polled by Datadog's [Cassandra integration].

Cassandra's own custom metrics are exposed under
**org.apache.cassandra.db**. For example, the custom read and write
latency metrics are accessed under
**org.apache.cassandra.db:type=StorageProxy,Attribute=xxx**. This data
is not tracked by Datadog's Cassandra integration. That's ok though,
since it can be added to Datadog just as any JMX data can be.

The following data is available through the **\*.metrics** (i.e.
Dropwizard) interface. I break them up into two groups since that is how
Dropwizard breaks up their implementation internally. Note that these
names are not reflected in JMX, that is to say there are no "histogram"
nor "meter" components in the JMX path specifications.

One note here is that the term histogram is a misnomer for the data
being provided here. A histogram is a *count of data points* which fall
into buckets, where each bucket represents a distinct range of values.

That's not what the Dropwizard bean supplies. It instead supplies
[quantiles]. A quantile is a data point *value* (not a *count of data
points*) which is higher than the values of a certain proportion of all
data points (say, 75% of all data points).

While they get at the same idea in that they represent information about
the underlying distribution of data points, they take different forms
and go about it different ways, so they can't be directly compared in a
graph, for example.

Here they are:

-   **Histogram:** - distribution of the latency of the operations
    (read/write). The underlying sample on which the percentiles are
    based is continually updated and [heavily biased] to the last five
    minutes. The rest of the metrics (count, mean, etc.) are not biased
    and instead are for the lifetime of the service.

    -   **durationUnit** - the unit of the returned latency values,
        namely microseconds

    -   **50thPercentile** - the median value

    -   **75th, 95th, 98th, 99th, 999thPercentile** - the values higher
        than 75%, … and 99.9% of the data points respectively

    -   **Count/Mean/StdDev/Min/Max** - the count/average/standard
        deviation/minimum/maximum of data points tracked since the
        beginning of time

-   **Meter** - the rate of events

    -   **EventType** - what's being measured by these metrics, namely
        rate of calls (i.e. read/write operations, not latency)

    -   **RateUnit** - the unit of the returned rates, namely operations
        per second

    -   **MeanRate** - average rate over the lifetime of the service

    -   **One, Five, FifteenMinuteRate** - one, five and fifteen-minute
        exponential moving average rate of operations. These are still
        operations-per-second rates, but averages over a window of the
        last one/five/fifteen minutes.

Write latency in this context means the amount of time for a Cassandra
node to successfully replicate to the required set of nodes, based on
the write consistency setting, and get acknowledgements. Cassandra calls
this a mutation, which is different from, say, what you might think of
as a write to a disk. Mutation includes replication to the cluster. You
can see the how the statistics are updated in the [`mutate`] method by
the [`writeMetrics`].[`addNano`] call. (note that Dropwizard tracks raw
data in nanoseconds, but can be configured to report in any time unit,
which Cassandra sets to microseconds.)

You can find the mappings of attribute names to code in the Dropwizard
[JMX reporter] and the implementation of the metrics in the Dropwizard
[Timer code], [Meter code] and [Histogram code]. The Dropwizard version
used by Cassandra 2.1.13 is 2.2.0, per the [build file], and is called
"yammer" instead of "dropwizard" because of the history of that project.

### Understanding the Metrics

Dropwizard offers a set of standardized classes which form the basis of
different kinds of metrics. They range from the most basic, the counter,
to the most exotic, the Timer. The classes perform the task of
maintaining values and doing the basic calculations required for, say,
minimum and maximum.

They also expose themselves in JMX via an MBean, so there is a standard
way to access each type. They allow the user of the library to define
the name of the bean that exposes the Dropwizard metrics "scope" vary
based on how you instantiate the classes.

For Cassandra's write latency metrics, it employs a Timer. Each time a
node performs a client's write request, a regular (not Dropwizard) timer
is started. When the write has been propagated to the replicas and
acknowledged, the timer is stopped and the duration of the operation in
nanoseconds is submitted first to Cassandra's ClientRequestMetrics
object, which in turn submits it to the Dropwizard Timer instance. The
ClientRequestMetrics instance employs a few other fields to track
related metrics such as timeouts (a Dropwizard Counter), but I won't be
discussing those.

A [Timer] tracks both the rate at which some code is called, as well as
the distribution of durations that the code took. It does this by
receiving a sample duration each time it is updated.

The Timer in turn is composed of two other Dropwizard classes: a [Meter]
and [Histogram]. The Meter tracks the rate of events, including three
different moving averages. The Histogram tracks the durations given by
the data points, and allows you to ask for a fixed set of [percentiles].
Again, calling this a histogram is a misnomer, but that's the last time
I'll mention it.

The percentiles are the most interesting piece of this since you can get
a perspective of the durations of a wide swath of your writes, and they
tell you about what's been going on recently. Tracking these in Datadog
allows you to see a picture over a wide time-range as well.

### Examining the Implementation through Code

Walking through the implementation of one of the exposed metrics will
let you see how easy it is to understand the others. The Cassandra and
Dropwizard code are both very readable.

Let's do one of the Dropwizard ones since that is fewer steps. Here's
where [Cassandra initializes] the latency metrics:

``` java
[...]
import org.apache.cassandra.metrics.*

[...]
public class StorageProxy implements StorageProxyMBean
{
    [...]

    private static final ClientRequestMetrics writeMetrics = new ClientRequestMetrics("Write");

    [...]
}
```

> src/java/org/apache/cassandra/service/StorageProxy.java, line 92

**writeMetrics** is the instance of
**org.apache.cassandra.metrics.ClientRequestMetrics** which tracks
client write requests.

It's initialized with the the argument **"Write"**, which translates to
the "scope" parameter for the related MBean published by JMX.  The
"type" parameter of the same JMX interface is "ClientRequest".

Here's the [ClientRequestMetrics] definition:

``` java
public class ClientRequestMetrics extends LatencyMetrics
{
    [...]
    public ClientRequestMetrics(String scope)
    {
        super("ClientRequest", scope);
        [...]
    }
```

> src/java/org/apache/cassandra/metrics/ClientRequestMetrics.java, line
> 29

Ok, so that's just a wrapper around LatencyMetrics. (I edited out some
other attributes I wasn't interested in)

Let's look at [LatencyMetrics] then:

``` java
public class LatencyMetrics
{
    /** Latency */
    public final Timer latency;
    /** Total latency in micro sec */
    public final Counter totalLatency;

    [...]

    @Deprecated public final EstimatedHistogram totalLatencyHistogram = new EstimatedHistogram();
    @Deprecated public final EstimatedHistogram recentLatencyHistogram = new EstimatedHistogram();

    [...]

    public LatencyMetrics(MetricNameFactory factory, String namePrefix)
    {
        [...]

        latency = Metrics.newTimer(factory.createMetricName(namePrefix + "Latency"), TimeUnit.MICROSECONDS, TimeUnit.SECONDS);
        totalLatency = Metrics.newCounter(factory.createMetricName(namePrefix + "TotalLatency"));
    }

    [...]
}
```

> src/java/org/apache/cassandra/metrics/LatencyMetrics.java, line 34

So there are a couple items that may be interesting here:

-   **latency** - a Dropwizard Timer - this is the big one. You can see
    that it is initialized with the TimeUnit MICROSECONDS for the
    latency reporting and SECONDS (really ops/s) for the rate reporting.

-   **totalLatency** - a Counter which is used to total the latency for
    all writes since the system start.  There is no timeunit specified,
    but it is updated with nanos/1000 when it is incremented, i.e.
    microseconds

-   **totalLatencyHistogram** - Cassandra's custom histogram for all
    time

-   **recentLatencyHistogram** - Cassandra's custom histogram cleared
    each time it's read

While it may seem like I'd be interested in the recentLatencyHistogram,
that is actually the custom Cassandra version of the histogram
([EstimatedHistogram]). I'm interested in Dropwizard's quantiles (a.k.a.
Histogram). Those are inside the Timer called "latency" here.

At this point, I've made it through Cassandra's initialization code to
the point where it has created the Dropwizard object in which I'm
interested.  That's all I was interested at first, to see exactly what
it was using from that library.

Knowing now that it really is a Timer, I want to look at the Timer's JMX
information next. Let's find the [MBean definition for Dropwizard's
Timer]:

``` java
    public interface TimerMBean extends MeterMBean, HistogramMBean {
        TimeUnit getLatencyUnit();
    }
```

> metrics-core/src/main/java/com/yammer/metrics/reporting/JmxReporter.java,
> line 258

That's just an extension of the [HistogramMBean], which is where the
quantiles are:

``` java
    public interface HistogramMBean extends MetricMBean {
        long getCount();

        double getMin();

        double getMax();

        double getMean();

        double getStdDev();

        double get50thPercentile();

        double get75thPercentile();

        double get95thPercentile();

        double get98thPercentile();

        double get99thPercentile();

        double get999thPercentile();

        double[] values();
    }
```

> metrics-core/src/main/java/com/yammer/metrics/reporting/JmxReporter.java,
> line 154

Finally, now we're getting somewhere! These method names, minus the
"get" prefix, are the attributes exposed to JMX! Let's look at what's
behind **get50thPercentile**. For that, we need to look at the
[HistogramMBean implementation]:

``` java
    private static class Histogram implements HistogramMBean {
        [...]
        private final com.yammer.metrics.core.Histogram metric;

        [...]

        @Override
        public double get50thPercentile() {
            return metric.getSnapshot().getMedian();
        }
        [...]
    }
```

> metrics-core/src/main/java/com/yammer/metrics/reporting/JmxReporter.java,
> line 181

This is somewhat confusing because Dropwizard calls its MBean
implementation class a Histogram the same as the Histogram metric class
itself, but they are two different classes as you can see.

So here we have a Histogram object from the metrics.core package being
called to satisfy the JMX request.

If you look at **Histogram\#getSnapshot**, you'll see that there's some
extra stuff going on, namely that there's a sampling pool of the data
points which is being managed by Dropwizard to track events, with an
algorithm that weights recent data more heavily. It also converts from
nanoseconds to microseconds. We'll skip that.

Suffice to say that Histogram holds a [Sample] implementation (an
[ExponentiallyDecayingSample] in our case), which is being updated with
write latencies. When getSnapshot is called, it makes a [Snapshot] copy
of the sample which can then have calculations run on it.

When **Snapshot\#getMedian** is called, it calls [**getValue**] with an
argument representing the 50th percentile:

``` java
    public double getValue(double quantile) {
        [...]

        final double pos = quantile * (values.length + 1);

        [...]

        final double lower = values[(int) pos - 1];
        final double upper = values[(int) pos];
        return lower + (pos - floor(pos)) * (upper - lower);
    }
```

> metrics-core/src/main/java/com/yammer/metrics/stats/Snapshot.java,
> line 54

Here, quantile is 0.5.  I'm not so much interested in understanding how
it calculates the median in this case, so I'm not going to try to
understand or explain the code above.  Instead I'm interested in knowing
that I can track down how the code works whenever I do have a question
about how it works precisely, as we've done here.

So that's how the data comes out through the MBean.  Mission
accomplished so far.  The next question is how it gets in there in the
first place.

For that we have to go back to where Cassandra uses the metrics, in
[`mutate`]: (there's one other method like mutate which also updates
these metrics btw)

``` java
    public static void mutate(Collection<? extends IMutation> mutations, ConsistencyLevel consistency_level)
    throws UnavailableException, OverloadedException, WriteTimeoutException
    {
        Tracing.trace("Determining replicas for mutation");
        [...]

        long startTime = System.nanoTime();

        [...]

        try
        {
            [writing stuff to replicas]
        }
        catch (WriteTimeoutException ex)
        {
            if (consistency_level == ConsistencyLevel.ANY)
            {
              [no other metric is tracked here, but latency is still tracked]
            }
            else
            {
                writeMetrics.timeouts.mark();
                ClientRequestMetrics.writeTimeouts.inc();
                Tracing.trace("Write timeout; received {} of {} required replies", ex.received, ex.blockFor);
                throw ex;
            }
        }
        catch (UnavailableException e)
        {
            writeMetrics.unavailables.mark();
            ClientRequestMetrics.writeUnavailables.inc();
            Tracing.trace("Unavailable");
            throw e;
        }
        catch (OverloadedException e)
        {
            ClientRequestMetrics.writeUnavailables.inc();
            Tracing.trace("Overloaded");
            throw e;
        }
        finally
        {
            writeMetrics.addNano(System.nanoTime() - startTime);
        }
    }
```

> src/java/org/apache/cassandra/service/StorageProxy.java, line 554

If exceptions occur, most of them mark specific metrics to denote their
occurrence.  In all cases, **addNano** is called by the **finally**
block, which ends up adding the measured latency to the Dropwizard
Histogram.  The Histogram in turn updates the sample pool internally.
Cassandra's own EstimatedHistogram also gets the update, but tracing
that path is an exercise for the reader.

At this point I should note that there's a lot of information in the
latency sample...not only successful writes, but also unsuccessful ones
with any type of exception, which may mean several different modes in
the resulting data.  Unfortunately, in practice this means that the
resulting metrics aren't always terribly useful at describing the what's
actually going on with the sample because there's too little
information!

For example, I can only get 50th, 75th and 99th percentile from my
Datadog implementation.  I can't modify its configuration, and even if I
could, JMX would only allow me to add 95th and 99.9th, which still isn't
enough.  In practice, the graph of these points over time is dominated
by the 99th percentile, which dwarfs the others and makes 50th and 75th
look identical.  That's because we have been seeing high exception rates
in the writes, which puts 50th and 75th in a small band of good,
performant write values, while the 99th is way out in the tail of the
bad write values.

To address this, I've started pulling the EstimatedHistogram results
directly from JMX, which contains 90+ buckets and provides a granular
enough picture to see all of the modes in the distribution.  I've only
started playing with this, and visualization (not to mention data
collection) is difficult, but because the different write latencies
(success, failure modes) aren't available separately, this seems to be
the only way to inspect the data usefully.

With that, you should have a shot at tracing down the exact behavior of
any of Cassandra's published metrics!

If you'd like to dive deeper, here are two resources I found useful to
understand the topic. The [first] is a presentation by one of the
DataStax developers discussing the metrics implementation. I thought it
was particularly nice of him to go through the changes through history,
which helped with the version I was looking for. While he seems to throw
some shade on the usefulness of Dropwizard's Histogram (quantiles), a)
the Cassandra replacement has a number of its own issues, one of which
is that it's not easily consumable by Datadog and therefore not very
useful, and b) they were more interested in the storage size of the data
structure for historical tracking, which is not such a concern in the
first place since it should be done outside Cassandra anyway with a
collector like Datadog.

The [second] is a presentation by the developer of the Dropwizard
metrics library. While this one ranges over more topics than I'm
interested in, the parts which do apply were also very useful. I've made
the link start at the point in the video where he begins talking about
the constructs used by the write latency metrics.

Finally, while not related to metrics, I also want to point out [this
presentation on Cassandra tuning], which I found very detailed, since
fixing an issue with Cassandra performance was the reason I began
looking at write latencies in the first place.

  [Dropwizard metrics]: https://metrics.dropwizard.io/4.1.2/
  [Cassandra integration]: https://github.com/DataDog/integrations-core/blob/master/cassandra/datadog_checks/cassandra/data/conf.yaml.example#L146
  [quantiles]: http://www.techbookreport.com/tutorials/quantiles.html
  [heavily biased]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/core/Histogram.java#L41
  [`mutate`]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/service/StorageProxy.java#L554
  [`writeMetrics`]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/service/StorageProxy.java#L632
  [`addNano`]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/metrics/LatencyMetrics.java#L105
  [JMX reporter]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/reporting/JmxReporter.java#L263
  [Timer code]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/core/Timer.java
  [Meter code]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/core/Meter.java
  [Histogram code]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/core/Histogram.java
  [build file]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/build.xml#L403
  [Timer]: https://metrics.dropwizard.io/4.1.2/getting-started.html#timers
  [Meter]: https://metrics.dropwizard.io/4.1.2/getting-started.html#meters
  [Histogram]: https://metrics.dropwizard.io/4.1.2/getting-started.html#histograms
  [percentiles]: https://www.mathsisfun.com/data/percentiles.html
  [Cassandra initializes]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/service/StorageProxy.java#L92
  [ClientRequestMetrics]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/metrics/ClientRequestMetrics.java#L29
  [LatencyMetrics]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/metrics/LatencyMetrics.java#L34
  [EstimatedHistogram]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/utils/EstimatedHistogram.java#L33
  [MBean definition for Dropwizard's Timer]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/reporting/JmxReporter.java#L258
  [HistogramMBean]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/reporting/JmxReporter.java#L154
  [HistogramMBean implementation]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/reporting/JmxReporter.java#L181
  [Sample]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/stats/Sample.java#L6
  [ExponentiallyDecayingSample]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/stats/ExponentiallyDecayingSample.java#L23
  [Snapshot]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/stats/Snapshot.java#L13
  [**getValue**]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/stats/Snapshot.java#L54
  [first]: https://www.youtube.com/watch?v=vcniEFmFY0E
  [second]: https://www.youtube.com/watch?v=czes-oa0yik&t=12m30s
  [this presentation on Cassandra tuning]: https://www.youtube.com/watch?v=bQRjfHwjAL4

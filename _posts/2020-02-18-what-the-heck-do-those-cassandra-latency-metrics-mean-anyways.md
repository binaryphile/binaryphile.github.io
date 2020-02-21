---
layout: post
title: "What the Heck do those Cassandra Latency Metrics Mean, Anyways?"
date: 2020-02-18 14:15 UTC
categories: [ metrics, cassandra ]
---

I recently looked at a DataDog graph of Cassandra client write latencies
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
implementation underneath the **org.apache.cassandra.metrics**
bean. For example, the client request write latency metrics are
accessed under
**org.apache.cassandra.metrics:type=ClientRequest,scope=Write,name=Latency,Attribute=xxx**.
This is the data being polled by DataDog's Cassandra integration.

Cassandra's own custom metrics are exposed under
**org.apache.cassandra.db**. For example, the custom read and write
latency metrics are accessed under
**org.apache.cassandra.db:type=StorageProxy,Attribute=xxx**. This data
is not tracked by DataDog's Cassandra integration. That's ok though,
since it can be added to DataDog just as any JMX data can be.

The following data is available through the **\*.metrics** (i.e.
Dropwizard) interface. I break them up into two groups since that is how
Dropwizard breaks up their implementation internally. Note that these
names are not reflected in JMX, that is to say there are no "histogram"
nor "meter" components in the JMX path specifications.

One note here is that the term histogram is a misnomer for the data
being provided here.  A histogram is a *count of data points* which fall
into buckets, where each bucket represents a distinct range of values.

That's not what the Dropwizard bean supplies.  It instead supplies
quantiles.  A quantile is a data point *value* (not a *count of data
points*) which is higher than the values of a certain proportion of all
data points (say, 75% of all data points).

While they get at the same idea in that they represent information about
the underlying distribution of data points, they take different forms
and go about it different ways, so they can't be directly compared in a
graph, for example.

Here they are:

-   **Histogram:** - distribution of the latency of the operations
    (read/write). The percentiles are [heavily biased] to the last five
    minutes. The count, mean, etc. metrics other than the percentiles
    are not biased and instead are for the lifetime of the service.

    -   **durationUnit** - the unit of the returned latency values,
        namely milliseconds

    -   **50thPercentile** - the median value

    -   **75th, 95th, 98th, 99th, 999thPercentile** - the values higher
        than 75%, … and 99.9% of the data points respectively

    -   **Count/Mean/StdDev/Min/Max** - the count/average/standard
        deviation/minimum/maximum of data points tracked since the
        beginning of time

-   **Meter** - the rate of events

    -   **EventType** - what's being measured by these metrics, namely
        rate of calls (i.e. read/write operations, not latency)

    -   **RateUnit** - the unit of the returned rates, namely seconds

    -   **MeanRate** - average rate over the lifetime of the service

    -   **One, Five, FifteenMinuteRate** - one, five and fifteen-minute
        exponential moving average rate of operations

Write latency in this context means the amount of time for a Cassandra
node to successfully replicate to the required set of nodes, based on
quorum level, and get acknowledgements. Cassandra calls this a mutation,
which is different from, say, what you might think of as a write to a
disk.  Mutation includes replication to the cluster.  You can see the
how the statistics are updated in the [`mutate`] method by the
[`writeMetrics`].[`addNano`] call. (note that Dropwizard tracks raw data
in nanoseconds, but reports in milliseconds.)

You can find the mappings of attribute names to code in the Dropwizard
[JMX reporter] and the implementation of the metrics in the Dropwizard
[Timer code], [Meter code] and [Histogram code]. The Dropwizard version
used by Cassandra 2.1.13 is 2.2.0, per the [build file], and is called
"yammer" instead of "dropwizard" because of the history of that project.

### Understanding the Metrics

Dropwizard offers a set of standardized classes which form the basis of
different kinds of metrics.  They range from the most basic, the
counter, to the most exotic, the Timer.  The classes perform the task of
maintaining values and doing the basic calculations required for, say,
minimum and maximum.

They also expose themselves in JMX via an MBean, so there is a standard
way to access each type.  They allow the user of the library to define
the name of the bean that exposes the Dropwizard metrics
"scope" vary based on how you instantiate the classes.

For Cassandra's write latency metrics, it employs a Timer.  Each time a
node performs a client's write request, a regular (not Dropwizard) timer
is started.  When the write has been propagated to the replicas and
acknowledged, the timer is stopped and the duration of the operation in
nanoseconds is submitted first to Cassandra's ClientRequestMetrics
object, which in turn submits it to the Dropwizard Timer instance.  The
ClientRequestMetrics instance employs a few other fields to track
related metrics such as timeouts (a Dropwizard Counter), but I'll
discuss those later.

A [Timer] tracks both the rate at which some code is called, as well as
the distribution of durations that the code took.  It does this by
receiving a sample duration each time it is updated.

The Timer in turn is composed of two other Dropwizard classes: a [Meter]
and [Histogram].  The Meter tracks the rate of events, including three
different moving averages.  The Histogram tracks the durations given by
the data points, and allows you to ask for a fixed set of [percentiles].
Again, calling this a histogram is a misnomer, but that's the last time
I'll mention it.

The percentiles are the most interesting piece of this since you can get
a perspective of the durations of a wide swath of your writes, and they
tell you about what's been going on recently.  Tracking these in DataDog
allows you to see a picture over a wide time-range as well.

### Examining the Implementation through Code

Walking through the implementation of one of the exposed metrics will
let you see how easy it is to understand the others.  The Cassandra and
Dropwizard code are both very readable.

Let's do one of the Dropwizard ones since that is fewer steps.  Here's
where [Cassandra initializes] the latency metrics:

```java
    private static final ClientRequestMetrics writeMetrics = new ClientRequestMetrics("Write");
```

Here's the [ClientRequestMetrics] definition:

```java
public class ClientRequestMetrics extends LatencyMetrics
{
    [...]
    public ClientRequestMetrics(String scope)
    {
        super("ClientRequest", scope);
        [...]
    }
```

Ok, so that's just a wrapper around LatencyMetrics. (I edited out some
other attributes I wasn't interested in)

Let's look at [LatencyMetrics] then:

```java
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

While it may seem like I'd be interested in the recentLatencyHistogram,
that is actually the custom Cassandra version of the histogram.  I'm
interested in Dropwizard's quantiles (a.k.a. Histogram).  Those are
inside the Timer called "latency" here.

Since I know I want to look at the Timer's JMX information, let's find
the [MBean definition for Dropwizard's Timer]:

```java
    public interface TimerMBean extends MeterMBean, HistogramMBean {
        TimeUnit getLatencyUnit();
    }
```

That's just an extension of the [HistogramMBean], which is where the
quantiles are:

```java
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

Finally, now we're getting somewhere!  These method names, minus the
"get" prefix, are the attributes exposed to JMX!  Let's look at what's
behind **get50thPercentile**.  For that, we need to look at the
[HistogramMBean implementation]:

```java
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

So here we have a Histogram object from the metrics.core package being
called to satisfy the attribute request.

If you look at **Histogram#getSnapshot**, you'll see that there's some
extra stuff going on, namely that there's a sampling pool of the data
points which is being managed by Dropwizard to track events with an
algorithm that weights recent data more heavily.  It also converts from
nanoseconds to milliseconds.  We'll skip that.

The important part is [**getValue**], which pulls the 50th percentile
from the sample values when supplied the proper argument:

```java
    public double getValue(double quantile) {
        [...]

        final double pos = quantile * (values.length + 1);

        [...]

        final double lower = values[(int) pos - 1];
        final double upper = values[(int) pos];
        return lower + (pos - floor(pos)) * (upper - lower);
    }
```

Here, quantile is 0.5.

So that's how the data comes out through the MBean.  How does it get in
there in the first place?  For that we have to go back to where
Cassandra uses the metrics, in [`mutate`]: (there's another method like
mutate which also updates metrics too)

```java
    public static void mutate(Collection<? extends IMutation> mutations, ConsistencyLevel consistency_level)
    throws UnavailableException, OverloadedException, WriteTimeoutException
    {
        Tracing.trace("Determining replicas for mutation");
        [...]

        long startTime = System.nanoTime();

        [...]

        try
        {
            [writing stuff]
        }
        catch (WriteTimeoutException ex)
        {
            if (consistency_level == ConsistencyLevel.ANY)
            {
              [...]
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

If there are no exceptions (most of which mark their own metrics), then
**addNano** is called, which ends up adding itself to the Histogram,
which then updates its sample pool internally.  Cassandra's own
EstimatedHistogram also gets the update, but tracing that path is an
exercise for the reader.

With that, you should have a shot at tracing down the exact behavior of
any of Cassandra's published metrics!

  [Dropwizard metrics]: https://metrics.dropwizard.io/4.1.2/
  [heavily biased]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/core/Histogram.java#L41
  [`mutate`]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/service/StorageProxy.java#L554
  [`writeMetrics`]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/service/StorageProxy.java#L632
  [`addNano`]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/metrics/LatencyMetrics.java#L105
  [JMX reporter]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/reporting/JmxReporter.java#L263
  [Timer code]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/core/Timer.java
  [Meter code]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/core/Meter.java
  [Histogram code]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/core/Histogram.java
  [build file]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/build.xml#L403
  [domain]: https://docs.oracle.com/javase/tutorial/jmx/mbeans/standard.html
  [Timer]:  https://metrics.dropwizard.io/4.1.2/getting-started.html#timers
  [Meter]: https://metrics.dropwizard.io/4.1.2/getting-started.html#meters
  [Histogram]: https://metrics.dropwizard.io/4.1.2/getting-started.html#histograms
  [percentiles]: https://www.mathsisfun.com/data/percentiles.html
  [Cassandra initializes]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/service/StorageProxy.java#L92
  [ClientRequestMetrics]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/metrics/ClientRequestMetrics.java#L29
  [LatencyMetrics]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/metrics/LatencyMetrics.java#L34
  [MBean definition for Dropwizard's Timer]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/reporting/JmxReporter.java#L258
  [HistogramMBean]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/reporting/JmxReporter.java#L154
  [HistogramMBean implementation]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/reporting/JmxReporter.java#L181
  [**getValue**]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/stats/Snapshot.java#L54

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

In Cassandra 2.1.13, client request read and write metrics are tracked
by both the Dropwizard library code as well as custom Cassandra code
written outside the Dropwizard code.

The Dropwizard metrics are exposed via Dropwizard's own MBean underneath
the **org.apache.cassandra.metrics** interface. For example, the client
request write latency metrics are accessed under
**org.apache.cassandra.metrics:type=ClientRequest,scope=Write,name=Latency,Attribute=xxx**.
This is the data being polled by DataDog's Cassandra integration.

The custom metrics are exposed under **org.apache.cassandra.db**. For
example, the custom read and write latency metrics are accessed under
**org.apache.cassandra.db:type=StorageProxy,Attribute=xxx**. This data
is not tracked by DataDog's Cassandra integration. That's ok though,
since that histogram data is not digested into a percentile format and
is also not as good as the Dropwizard data.

The following data is available through the **.metrics** (i.e.
Dropwizard) interface. I break them up into two groups since that is how
Dropwizard breaks up their implementation internally. Note that these
names are not reflected in JMX, that is to say there are no "histogram"
nor "meter" components in the JMX path specifications.

Here they are:

-   **Histogram:** - distribution of the latency of the operations
    (read/write). The percentiles are [heavily biased] to the last five
    minutes. The count, mean, etc. other metrics are not biased and
    instead are for the lifetime of the service.

    -   **durationUnit** - the unit of the returned latency values,
        namely milliseconds

    -   **50thPercentile** - the median value

    -   **75th, 95th, 98th, 99th, 999thPercentile** - the values higher
        than 75%, … and 99.9% of the data points respectively

    -   **Count/Mean/StdDev/Min/Max** - the count of/average/standard
        deviation/minimum/maximum of data points added to the histogram
        since the beginning of time

-   **Meter** - the rate of events

    -   **EventType** - what's being measured by these metrics, namely
        rate of calls (i.e. read/write operations, not latency)

    -   **RateUnit** - the unit of the returned rates, namely seconds

    -   **MeanRate** - average rate over the lifetime of the service

    -   **One, Five, FifteenMinuteRate** - one, five and fifteen-minute
        exponential moving average rate of operations

Write latency in this context means the amount of time for a Cassandra
node to successfully replicate to the required set of nodes, based on
quorum level, and get acknowledgements. You can see the how the
statistics are updated by the in [`mutate`] by the
[`writeMetrics`].[`addNano`] call. (Dropwizard tracks raw data in
nanoseconds, but reports in milliseconds.)

You can find the mappings of attribute names to code in the Dropwizard
[JMX reporter] and the implementation of the metrics in the Dropwizard
[Timer], [Meter] and [Histogram] source code. The Dropwizard version
used by Cassandra 2.1.13 is 2.2.0, per the [build file], and is called
"yammer" instead of "dropwizard" because of the history of that project.

  [heavily biased]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/core/Histogram.java#L41
  [`mutate`]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/service/StorageProxy.java#L554
  [`writeMetrics`]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/service/StorageProxy.java#L632
  [`addNano`]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/src/java/org/apache/cassandra/metrics/LatencyMetrics.java#L105
  [JMX reporter]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/reporting/JmxReporter.java
  [Timer]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/core/Timer.java
  [Meter]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/core/Meter.java
  [Histogram]: https://github.com/dropwizard/metrics/blob/v2.2.0/metrics-core/src/main/java/com/yammer/metrics/core/Histogram.java
  [build file]: https://github.com/apache/cassandra/blob/cassandra-2.1.13/build.xml#L403

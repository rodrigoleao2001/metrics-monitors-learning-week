# Day 1 APM Scenario

Read this before you start the lab. It sets the rules of the exercise, introduces the service, tells you how to bring the environment up, and frames each mission so you can start investigating without anyone telling you where to look. It is not the whole lab guide. `day1-apm/LAB.md` stays the source of truth for the stretch work and the expert defense questions, so keep it open beside this document. Neither document contains the cause or the fix for any mission. Bring your evidence to the group discussion instead of looking for the answer here.

## Working Rules

This lab is a support case simulation, not a query copying exercise. Form a hypothesis before you change a monitor, capture the evidence that supports it, and be ready to defend the trade off between detection speed, noise, ownership, routing, and message clarity. Capture that evidence as a query, a graph, a screenshot, or a monitor state.

Every metric name, tag and threshold you need is already visible in the monitor's own query, so read the query first and carry those same names into Metrics Explorer rather than guessing at a namespace.

Not every monitor in this lab is wrong. Most missions ask you to prove a monitor is missing something, but one mission gives you a monitor that is already correctly built, and your job there is to prove the alert is real before anyone touches it. Do not assume a monitor is broken just because this is a training lab. Read the evidence first.

Each mission has three levels. The core path is to prove what is broken and make the monitor detect the real issue, or to prove the alert is legitimate. The stretch challenge is to compare at least two valid fixes and explain the trade off between them. The expert defense is to explain how your own fix could still fail in production and how you would validate it after release. `LAB.md` carries a per mission version of the stretch and expert questions.

## Starting the Lab

This lab runs on your own machine against your own Datadog org, so have an API key and an application key ready before you begin. From the root of the Learning Week folder run `./setup_day1_apm.sh`, then confirm the result with `./check_day1_apm.sh`. Run only this day, because the whole week does not fit in memory at once.

Data takes three to five minutes to reach Datadog after the first start, so empty graphs in the first minutes mean the lab is still filling rather than broken. Before you conclude that a graph is empty because your query is wrong, run `./check_day1_apm.sh` again. It reports container status, curls the local health endpoint at `http://localhost:5000/health`, and confirms that the trace metrics and the demo metrics are arriving. If the check reports a container that is not running, bring the lab back up before you spend time on the query.

## Finding the Monitors

Every monitor in this lab carries the tag `learning-week:day1-apm`. Go to Monitors and then Manage and paste `tag:learning-week:day1-apm` into the search box, and you get the whole lab and nothing else from your org. The service itself sits under APM and then Services as `flask-store`, scoped to `env:learning-week`.

That search returns eight monitors. Two of the nine missions in `LAB.md`, the composite monitor and the SLO burn rate mission, ask you to build your own monitor from scratch, so they have nothing pre-created to find. One of the eight, named `[Day1] DEMO - Monitor Evaluation Concepts`, is not a mission at all: nothing was planted in it, and there is nothing in it for you to diagnose, because the facilitator drives it live during the session to demonstrate Evaluation Window, Require Full Window, and New Group Delay. Leave it alone.

Every monitor name in this document is written exactly as it appears in that list, so you can paste a name straight into the search box.

## The Service

You support `flask-store`, an online store. Tickets keep arriving even though the monitors you inherited mostly look green. The store exposes a home page at `GET /`, a product search at `GET /search`, a product detail page at `GET /product/<int:product_id>`, order checkout and payment at `GET /checkout`, a stock availability check at `GET /inventory`, product recommendations at `GET /recommendations`, and a health check at `GET /health`.

The store is instrumented with APM, so its latency, request count and error count arrive under the `trace.flask.request` namespace, and checkout failures are also counted by a custom metric named `flask_store.checkout_errors`. A separate background job also reports `flask_store.batch_sync_records`, a catalog sync that is unrelated to live checkout traffic. Be aware that the trace metrics normalize route strings, so the value you will see in Datadog for the checkout route is `get_/checkout` and not `GET /checkout`. Typing a route the way it is written above returns an empty graph, so copy values from the monitor query itself or pick them from the tag list Metrics Explorer offers you rather than typing them by hand.

Traffic is generated continuously, including periodic bursts, so the graphs you see will keep changing while you investigate.

## The Situation

Several monitors were already created for `flask-store` before you joined the case. Most of them were built with a realistic mistake that a real customer could make. At least one of them was not, and treating it the same way as the others is itself a mistake. Your job in each mission is to figure out what is actually true of the monitor in front of you, not to assume it is simply wrong.

These monitors sit in your own Datadog org and nobody else is working in it, so edit them as freely as you need to and do not worry about disturbing a colleague's run. You can also create new monitors of your own if that is what proves your fix, or what proves a monitor should be left alone. If you want the original configuration kept for comparison, clone the monitor first and work on the copy.

## Evidence Log

Fill in this record for every mission before you touch any monitor configuration. Write down the customer symptom, meaning what the user or alert claims is wrong. Write down the query or view checked, meaning the metric, monitor query, or UI view you inspected. Write down hypothesis A, your most likely explanation, and hypothesis B, a possible alternative you rejected. Write down the evidence that proves A over B. Write down two fix options, the first and second possible monitor or query change, and the chosen fix, meaning what you would deploy and why. Finally write down the customer explanation, meaning how you would explain it without dumping query syntax.

Before you change any monitor, be ready to deliver the current monitor problem in one sentence, one rejected alternative hypothesis, two possible fixes and the trade off between them, the evidence that made you choose the final fix, and a customer ready explanation. `LAB.md` asks for the same five things in every mission, so this is the bar for the whole week and not just for Day 1.

## Recording Your Work

Record the evidence log in a Datadog Notebook, one entry per mission, using the same fields listed above. Notebooks live under Dashboards in the left navigation, where New Notebook creates one. Add the graphs and queries you inspect directly into the notebook, along with short notes explaining what each one shows and why you tested it. Write down how you arrived at your fix, not only the fix itself, so the notebook shows the full path of your investigation and not only a final answer.

Keep one notebook for the whole day and name it `Day1 APM` followed by your name, so it can be pulled up quickly when the group walks the evidence. Give each mission its own section in mission order, so a reader who was not with you can follow the path from symptom to fix.

## Knowing When a Mission Is Done

A mission is finished when its evidence log is complete and you can deliver, without looking anything up again, the current monitor problem in one sentence, one rejected alternative hypothesis, two possible fixes and the trade off between them, the evidence that made you choose the final fix, and a customer ready explanation. If you can produce all six from memory, move on, even if you are not certain your fix is the one the facilitator had in mind. Defending a well evidenced wrong answer is worth more in the discussion than guessing the intended one.

If you get genuinely stuck, spend fifteen minutes writing down what you tested and why you rejected it before asking for a hint. That written trail is the point of the exercise, and it is also what makes a hint useful when you do ask.

## Mission 1: APM Latency

A customer writes in: shoppers are abandoning checkout because the store feels slow, but Datadog says everything is fine. The monitor named `[Day1] APM Latency` has read OK the whole time.

Before you open the monitor, plot `trace.flask.request` for the checkout endpoint in Metrics Explorer and describe its shape in your own words. Only then open the monitor and compare its query with what you just plotted. Inspect average, p95, and p99 for the checkout endpoint, then decide which statistic maps to user pain.

Ask yourself what a single number can and cannot tell you about how this endpoint feels to a user, when an average is the right summary and when it is the wrong one, and what the metric type actually allows you to calculate.

## Mission 2: APM Spike Detector

A customer writes in: there was a payment slowdown for maybe thirty seconds around lunch, and nobody got paged. `[Day1] APM Spike Detector` exists specifically to catch this kind of event.

Before you open the monitor, plot `trace.flask.request` for checkout over the last hour at the shortest rollup Metrics Explorer offers, and describe what a short slowdown looks like at that resolution. Then open the monitor named `[Day1] APM Spike Detector`. Read the query text in full, including everything applied after the metric name and the tag filter, and write down every time related setting you can find in it. Change the aggregation settings yourself in Metrics Explorer until the graph you are looking at disagrees with what the monitor reports.

Ask yourself what happens to a thirty second spike inside a long averaging window, what the trade off between sensitivity and noise looks like, and which way of summarising a window preserves the evidence you need.

## Mission 3: APM Error Surge

A customer writes in: a shopper hit an error during checkout, but the error dashboard for the service barely moved. The monitor named `[Day1] APM Error Surge` watches the whole service.

Before you open the monitor, plot `trace.flask.request.errors` for the whole service, then plot it again broken down `by {resource_name}`, and describe in your own words whether the two views tell the same story. Then open the monitor, read the query, and write down what it adds together and what it therefore cannot separate. Find out where the errors are actually coming from, by breaking the same metric down in Metrics Explorer or by working through the service in APM, and decide which of the dimensions available on that metric is the one that owns the action.

Ask yourself when grouping creates clarity, when grouping can create too many alerts at once, and what the difference is between finding a bad service and finding a bad endpoint.

## Mission 4: APM Throughput Alert

A customer writes in: they were paged at 3 AM for low traffic, and nothing was actually wrong. `[Day1] APM Throughput Alert` fired anyway.

Before you open the monitor, plot `trace.flask.request.hits` for the service over the last 24 hours and describe the daily shape you see, in your own words. Then open the monitor named `[Day1] APM Throughput Alert`. This one is not alerting right now, and that is part of the exercise rather than a broken environment. Read the threshold, the window and the no data settings, then compare what you already plotted against what the monitor is asking of the traffic.

Ask yourself what counts as normal low traffic, what should happen during off hours, and what you would want to happen when the metric stops arriving altogether, which is not the same thing as the metric being low.

## Mission 5: APM Inventory Latency, Second Opinion

`[Day1] APM Inventory Latency` moved from OK to Alert twenty minutes ago and is still alerting. Everyone in the room has just spent four missions finding a defect in every monitor they opened, and the temptation here is to assume this one is broken too and raise the threshold. Decide whether that assumption is justified before you act on it.

Open the monitor and read its query exactly as written: statistic, window, group-by, threshold. Compare it against the fix you argued for in Mission 1, and note anything it is already doing right. Then plot `trace.flask.request` p95 for the inventory endpoint in Metrics Explorer and compare it with the monitor's evaluated value. Pull individual inventory traces in APM and look for a downstream span that only appears on some requests, not all of them.

Ask yourself what evidence would prove this monitor is a false positive, what evidence would prove it is a true positive, and why "the query looks fine" is not enough evidence either way. Your answer has to rest on the trace-level evidence, not on the aggregate graph alone.

## Mission 6: Checkout Errors, Alert Volume Check

A customer writes in: their on-call channel is unusable, because they are getting paged constantly for what looks like the same issue over and over. `[Day1] Checkout Errors - Alert Volume Check` is the monitor behind it.

Before you open the monitor, plot `flask_store.checkout_errors` in Metrics Explorer without any group-by, then add a group-by and watch how many series appear. Describe what you see in your own words. Then open the monitor named `[Day1] Checkout Errors - Alert Volume Check`. Inspect which dimension the query groups by, then find out how many distinct values that dimension really takes, using both the monitor's own group list and the same metric in Metrics Explorer. Compare that with the other tags available on the same metric.

Ask yourself what makes a dimension a good group by choice and what makes it a poor one, what the group by choice does to the number of notifications a team receives, and which dimension would let one person own the fix for this failure.

## Mission 7: Composite Monitor, Both Bad at the Same Time

A customer writes in: they get paged separately for slow checkout and for checkout errors, but neither page alone tells them whether shoppers are actually affected. There is no pre-built monitor for this mission; you design it.

Plot `trace.flask.request` p95 for the checkout endpoint over the last hour, and plot `trace.flask.request.errors` rate for the same endpoint over the same window. Find a period where both are elevated at once and a period where only one is. The checkout team has told support that latency up to 5 seconds during the nightly batch job is expected on its own, and an error rate up to 2% during an active deploy is also expected on its own; only both conditions at once, regardless of batch or deploy, counts as a real incident.

Ask yourself whether a single metric can represent both conditions, or whether the two symptoms need two separate monitors joined by a composite, and what a composite monitor should do when one side of it has no data.

## Mission 8: SLO and Burn Rate, When Is the Budget Gone

A checkout SLO is set at 99% availability over a 30-day rolling window. The SLO is green right now. The burn rate is not. There is no pre-built monitor for this mission; you build the SLO and the alert yourself.

Create a request-based SLO using `trace.flask.request.hits` as the total and `trace.flask.request.errors` as bad events for the checkout endpoint, set the target at 99% over 30 days, then open the burn rate alert options and find the burn rate value at which the 30-day error budget would be consumed in 1 hour.

Ask yourself what an error budget of 1% over 30 days means in minutes of downtime per month, one scenario where a burn rate alert fires earlier than a simple error-rate threshold would, and one where it does not.

## Mission 9: Catalog Sync, The Monitor That Stopped Answering

The monitor named `[Day1] Catalog Sync - Records Processed` reads OK, and it has
read OK all week. The sync it watches stops for several minutes at a time, and
during those stretches the metric sends nothing at all, yet the monitor keeps
reading OK straight through them. Finance found a failed sync themselves, two
days later, while this monitor sat green.

Plot `flask_store.batch_sync_records` in Metrics Explorer over the last hour with
a one minute rollup, find the stretches with no points at all, and write down the
clock times. Then compare the monitor's state during those exact stretches with
what the metric was doing. To prove the cause rather than guess it, rebuild the
same query somewhere safe, change one evaluation setting, and watch what happens
during the next gap.

Ask yourself what a monitor should report when it cannot evaluate, and what the
difference is between a monitor that says OK and a monitor that has simply not
been asked the question recently. Your explanation has to account for a green
monitor that is in fact reporting nothing at all.

## Closing Note

Form a hypothesis first. Test it against the real query and graph. Reject at least one alternative explanation and note why. Come to the discussion ready to defend your fix, not just describe it. For the one mission where the monitor is correct, come ready to defend the evidence instead of a fix.

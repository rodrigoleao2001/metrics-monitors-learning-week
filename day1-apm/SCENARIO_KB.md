# Day 1 APM Scenario

Read this before you start the lab. It sets the rules of the exercise, introduces the service, tells you how to bring the environment up, and frames each mission so you can start investigating without anyone telling you where to look. It is not the whole lab guide. `day1-apm/LAB.md` stays the source of truth for the stretch work and the expert defense questions, so keep it open beside this document. Neither document contains the cause or the fix for any mission. Bring your evidence to the group discussion instead of looking for the answer here.

## Working Rules

This lab is a support case simulation, not a query copying exercise. Form a hypothesis before you change a monitor, capture the evidence that supports it, and be ready to defend the trade off between detection speed, noise, ownership, routing, and message clarity. Capture that evidence as a query, a graph, a screenshot, or a monitor state.

Every metric name, tag and threshold you need is already visible in the monitor's own query, so read the query first and carry those same names into Metrics Explorer rather than guessing at a namespace.

Each mission has three levels. The core path is to prove what is broken and make the monitor detect the real issue. The stretch challenge is to compare at least two valid fixes and explain the trade off between them. The expert defense is to explain how your own fix could still fail in production and how you would validate it after release. `LAB.md` carries a per mission version of the stretch and expert questions.

## Starting the Lab

This lab runs on your own machine against your own Datadog org, so have an API key and an application key ready before you begin. From the root of the Learning Week folder run `./setup_day1_apm.sh`, then confirm the result with `./check_day1_apm.sh`. Run only this day, because the whole week does not fit in memory at once.

Data takes three to five minutes to reach Datadog after the first start, so empty graphs in the first minutes mean the lab is still filling rather than broken. Before you conclude that a graph is empty because your query is wrong, run `./check_day1_apm.sh` again. It reports container status, curls the local health endpoint at `http://localhost:5000/health`, and confirms that the trace metrics and the demo metrics are arriving. If the check reports a container that is not running, bring the lab back up before you spend time on the query.

## Finding the Monitors

Every monitor in this lab carries the tag `learning-week:day1-apm`. Go to Monitors and then Manage and paste `tag:learning-week:day1-apm` into the search box, and you get the whole lab and nothing else from your org. The service itself sits under APM and then Services as `flask-store`, scoped to `env:learning-week`.

That search returns six monitors and only five of them are missions. The sixth is named `[Day1] DEMO - Monitor Evaluation Concepts`. Nothing was planted in it and there is nothing in it for you to diagnose, because the facilitator drives it live during the session to demonstrate Evaluation Window, Require Full Window, and New Group Delay. Leave it alone.

Every monitor name in this document is written exactly as it appears in that list, so you can paste a name straight into the search box.

## The Service

You support `flask-store`, an online store. Some users are unhappy with the experience, but the monitors you inherited mostly look green. The store exposes a home page at `GET /`, a product search at `GET /search`, a product detail page at `GET /product/<int:product_id>`, order checkout and payment at `GET /checkout`, a stock availability check at `GET /inventory`, product recommendations at `GET /recommendations`, and a health check at `GET /health`.

The store is instrumented with APM, so its latency, request count and error count arrive under the `trace.flask.request` namespace, and checkout failures are also counted by a custom metric named `flask_store.checkout_errors`. Be aware that the trace metrics normalize these route strings, so the value you will see in Datadog for the checkout route is `get_/checkout` and not `GET /checkout`. Typing a route the way it is written above returns an empty graph, so copy values from the monitor query itself or pick them from the tag list Metrics Explorer offers you rather than typing them by hand.

Traffic is generated continuously, including periodic bursts, so the graphs you see will keep changing while you investigate.

## The Situation

Several monitors were already created for `flask-store` before you joined the case. Each one was built with a realistic mistake that a real customer could make. Your job in each mission is to figure out what the monitor is missing, not to assume it is simply wrong.

These monitors sit in your own Datadog org and nobody else is working in it, so edit them as freely as you need to and do not worry about disturbing a colleague's run. You can also create new monitors of your own if that is what proves your fix. If you want the original configuration kept for comparison, clone the monitor first and work on the copy.

## Evidence Log

Fill in this record for every mission before you touch any monitor configuration. Write down the customer symptom, meaning what the user or alert claims is wrong. Write down the query or view checked, meaning the metric, monitor query, or UI view you inspected. Write down hypothesis A, your most likely explanation, and hypothesis B, a possible alternative you rejected. Write down the evidence that proves A over B. Write down two fix options, the first and second possible monitor or query change, and the chosen fix, meaning what you would deploy and why. Finally write down the customer explanation, meaning how you would explain it without dumping query syntax.

Before you change any monitor, be ready to deliver the current monitor problem in one sentence, one rejected alternative hypothesis, two possible fixes and the trade off between them, the evidence that made you choose the final fix, and a customer ready explanation. `LAB.md` asks for the same five things in every mission, so this is the bar for the whole week and not just for Day 1.

## Recording Your Work

Record the evidence log in a Datadog Notebook, one entry per mission, using the same fields listed above. Notebooks live under Dashboards in the left navigation, where New Notebook creates one. Add the graphs and queries you inspect directly into the notebook, along with short notes explaining what each one shows and why you tested it. Write down how you arrived at your fix, not only the fix itself, so the notebook shows the full path of your investigation and not only a final answer.

Keep one notebook for the whole day and name it `Day1 APM` followed by your name, so it can be pulled up quickly when the group walks the evidence. Give each mission its own section in mission order, so a reader who was not with you can follow the path from symptom to fix.

## Knowing When a Mission Is Done

A mission is finished when its evidence log is complete and you can deliver, without looking anything up again, the current monitor problem in one sentence, one rejected alternative hypothesis, two possible fixes and the trade off between them, the evidence that made you choose the final fix, and a customer ready explanation. If you can produce all six from memory, move on, even if you are not certain your fix is the one the facilitator had in mind. Defending a well evidenced wrong answer is worth more in the discussion than guessing the intended one.

If you get genuinely stuck, spend fifteen minutes writing down what you tested and why you rejected it before asking for a hint. That written trail is the point of the exercise, and it is also what makes a hint useful when you do ask.

## Mission 1: APM Latency, All Good

The monitor says latency is fine. Checkout users still report the store feels slow.

Open the monitor named `[Day1] APM Latency - All Good`. Compare the monitor query with the checkout endpoint latency in APM, under APM and then Services and then `flask-store`. Inspect average, p95, and p99 for the checkout endpoint, then decide which statistic maps to user pain.

Ask yourself what a single number can and cannot tell you about how this endpoint feels to a user, when an average is the right summary and when it is the wrong one, and what the metric type actually allows you to calculate.

## Mission 2: APM Spike Detector

This monitor is supposed to catch short latency spikes. It has stayed quiet through incidents that users noticed.

Open the monitor named `[Day1] APM Spike Detector`. Read the query text in full, including everything applied after the metric name and the tag filter, and write down every time related setting you can find in it. Then plot the same metric in Metrics Explorer and change the aggregation settings yourself until the graph you are looking at disagrees with what the monitor reports.

Ask yourself what happens to a thirty second spike inside a long averaging window, what the trade off between sensitivity and noise looks like, and which way of summarising a window preserves the evidence you need.

## Mission 3: APM Error Surge

The total error count for the service looks small. One endpoint may still be seriously broken underneath that total.

Open the monitor named `[Day1] APM Error Surge`. Read the query and write down what it adds together and what it therefore cannot separate. Then find out where the errors are actually coming from, by breaking the same metric down in Metrics Explorer or by working through the service in APM, and decide which of the dimensions available on that metric is the one that owns the action.

Ask yourself when grouping creates clarity, when grouping can create too many alerts at once, and what the difference is between finding a bad service and finding a bad endpoint.

## Mission 4: APM Throughput Alert

This monitor pages when traffic drops. Is every drop in traffic actually a problem, or does the alert fire on normal patterns too?

Open the monitor named `[Day1] APM Throughput Alert`. This one is not alerting right now, and that is part of the exercise rather than a broken environment. Read the threshold, the window and the no data settings, then plot the same metric in Metrics Explorer and work out what the traffic in this lab actually looks like across the time it has been running.

Ask yourself what counts as normal low traffic, what should happen during off hours, and what you would want to happen when the metric stops arriving altogether, which is not the same thing as the metric being low.

## Mission 5: Checkout Errors, Alert Volume Check

This monitor is supposed to catch checkout errors. It does fire, but it is producing a very large number of separate alert groups, and the on call team cannot tell from the notifications where the failure actually sits.

Open the monitor named `[Day1] Checkout Errors - Alert Volume Check`. Inspect which dimension the query groups by, then find out how many distinct values that dimension really takes, using both the monitor's own group list and the same metric in Metrics Explorer. Compare that with the other tags available on the same metric.

Ask yourself what makes a dimension a good group by choice and what makes it a poor one, what the group by choice does to the number of notifications a team receives, and which dimension would let one person own the fix for this failure.

## Closing Note

Form a hypothesis first. Test it against the real query and graph. Reject at least one alternative explanation and note why. Come to the discussion ready to defend your fix, not just describe it.

# hadoop
Deploy and manage Apache Hadoop with resin.io

Overview
--------
This project downloads a recent Apache Hadoop (version 2.8.1 at time of
writing) and deploys it to all the devices that are part of the resin.io
application.

The Hadoop NameNode is deployed on a single master node with all other devices
being deployed as DataNodes.  HDFS is shared across all devices and uses
persistent storage, so it should remain available across updates.  This has
*not* been extensively tested, so rely on the HDFS persistence at your own
risk!

This project requires at least two devices to be members of the application,
as the Data services will not be deployed on the master node.


Setup
-----
First create a resin.io application.  If you need instructions for this,
consult the [Getting Started Guide](https://docs.resin.io/raspberrypi3/nodejs/getting-started).

Two fleet-wide application variables must be set for the Hadoop cluster to
properly configure and start.  To set these variables, go to the Application
view (not an individual device) in the resin.io dashboard and click
"Environment Variables".

Create the following fleet-wide variables:

| Variable Name | Value |
| ------------- | ----- |
| MASTER_NODE   | Device ID to use for the master node |
| USER_API_KEY  | Your resin.io API key |

To find the **MASTER_NODE** Device ID, you will need to provision at least
one device with this application.  Then copy its UUID from the resin.io
dashboard.  (It is safe to start the application for the purpose of
provisioning without these values set; the application will simply stop
after booting until the values are properly set.)

To find the **USER_API_KEY** value, click your name in the upper right of the
resin.io dashboard, select Preferences, and select the Account details tab.
The API key is the "Auth Token" on this page.  Be sure to use the copy button
or click "show full" to copy the entire key.


Use
---
Once the setup is complete, Hadoop will be deployed and configured on the
cluster.  When ready, you will see something similar to the following on the
log view of the master node in the resin.io dashboard:

```
Hadoop services:
228 NameNode
550 ResourceManager
375 SecondaryNameNode

Ready to receive jobs
```

You can then log into the master node and submit jobs.


Known issues
------------
 * The Hadoop services are not optimized for speed or memory utilization, so
   jobs will run extremely slowly.
 * The Hadoop dashboard is running on port 8080 on the master node but is not
   yet exposed via a forwarded port 80 so that it can be viewed via a resin.io
   Public URL.
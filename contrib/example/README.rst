.. Copyright (c) 2017 RackN Inc.
.. Licensed under the Apache License, Version 2.0 (the "License");
.. DigitalRebar Provision documentation under Digital Rebar master license
..

.. _rs_example_integration:

Example Integration
~~~~~~~~~~~~~~~~~~~

This is an example-integration which shows how an integration with Digital Rebar Provision might be built.

This example utilizes the following components of the DRP Content system:

  * `params`: typed variable definitions
  * `stages`: a provisioning stage, to be inserted during workflow
  * `tasks`: composable blocks of work to be executed
  * `templates`: supporting content for tasks

The primary steps that are demonstrated by this example are as follows

  1. Set some `params` with values for API_KEY, SERVICE_URL, and Machine ID
  #. Create a `stage` to be used in workflow; which executes the `task` file `example-post-inventory.yaml`
  #. A `task` which enforces 'curl' being installed via `template` file `ensure-curl.sh.tmpl`
  #. A task which runs the `example.sh.tmpl` template, which collects the `gohai` inventory
  #. Additionally, 'hostname', 'date', 'IDENT' (param), and RS_UUID are injected in to the JSON blob

The final step is to call `curl` and POST the collected `gohai` inventory (along with additional metadata) to the SERVICE_URL (defined as user configurable `param` at run time).

NOTE that the "SERVICE_URL" is a mythical entity, and not provided as part of this example.  It simply demonstrates how an integration that sent a POST to a Service might look like. 


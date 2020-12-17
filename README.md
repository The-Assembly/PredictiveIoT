# Build a Predictive Analytics Model with Etisalat IoT Platform
Internet of Things workshop conducted on 19th December 2020 in association with Etisalat Digital and PTC.  

In this session, we will take the engine data obtained on the cloud and use ThingWorx Analytics Server to create an engine failure prediction model based on the same. We’ll use Analytics to visualise and refine our machine learning model iteratively based on statistical methods. Our system will then be able to predict outcomes based on new incoming data in real-time with our early warning capacity automatically improving as more data is made available.  

Prerequisites: Activate your free PTC Cloud trial developer account - https://developer.thingworx.com/en/resources/trials (No download required)

Instructions to run the EMS (optional):
1. Copy the contents of the EMS folder into C:\EMS (if you copy in to any other folder, you will need to alter etc\config.json)
2. Edit etc\config.json - replace {SERVER HOSTID} with your Thingworx server hostname (the URL of your server), replace {APPKEY} with an application key you have created in Thingworx Composer
3. Ensure an object called EdgeThing exists in Thingworx Composer with base template = RemoteThingWithTunnelsAndFileTransfer - import from XML file in Github if not there
4. Open a cmd window with dir C:\EMS - run wsems.exe - wait for the server to initialize before next step
5. Open another cmd window with dir C:\EMS - run luascriptresource.exe
The EMS will create edge objects that will sync with the cloud automatically.  If your edge object is not called EdgeThing - you need to edit etc\config.lua to match.

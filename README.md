# Real-time MEG

Various example scripts and test scripts for running real-time dataanalysis of MEG data at NatMEG (www.natmeg.se).

## About
NatMEG has implemented a setup for online processing of MEG and other recordings for real-time BCI. The setup is based on the FieldTrip buffer (for detailed information and documentation see the FieldTrip webpage: http://www.fieldtriptoolbox.org/development/realtime/).

The real-time MEG allows you to send data from the acquisition program to the stimulation PC as it is being recorded, e.g. to drive online feedback paradigms or brain computer interfaces. Below you find a short tutorial for getting started and setting up real-time MEG in the NatMEG lab. For technical information and further usage, please refer to the documentation page.

## Manual for using real-time MEG at NatMEG

### Step 1: send data from Acquisition PC

First open Acquisition on the acquisition compute and load project, settings, etc. as usual. Then open a new terminal window and type:

```octave
setUp_realTime
```

This starts the FieldTrip buffer. First it asks for “chunk size” of data-packages. Provide number of milliseconds of data to be sent. If no input is given it use the default of 1000 ms. Press enter. It then asks for scaling of data [yes/no, default: No]. Press enter. The buffer is now ready.

Press Start in Acquisition and collect data as usual. Data is now being transferred to the buffer.


**IMPORTANT**: When you are done with the buffer, it is important that you close the terminal window running the buffer by pressing **ctrl+c**. Do not close the terminal window by just pressing the X in the corner.


### Step 2: Receive data on stimulus

To recive data from the buffer to use in a real-time paradigm, you need to receive the data on the stimulation PC to facilitate further processing in the presentation software of your choice. Currently we use Matlab/FieldTrip (http://www.fieldtriptoolbox.org/) to receive and process data (code courtesy of Robert Oostenveld). Based on the features you want to extract from the online data, you can use it to trigger events in Matlab (e.g. through Psychtoolbox) or Presentation.


#### Read buffer-data in Matlab

Use the following IP to receive data from buffer. Specify as filename for FieldTrip to read and read get header information.

```octave
filename = 'buffer://130.229.40.57:1972';
hdr = ft_read_header(filename);
```

Specify user specific start/stop of data chunk to analyse.

```octave
windowsize  = 1;                    %The time-window to analyse (in seconds)
windowlen   = round(windowsize*hdr.Fs);
endsample   = hdr.nSamples;
begsample   = endsample - windowlen + 1;
```

Find only specific channels to process. This you have to figure out yourself, e.g.:

```octave
My_channels = find(~cellfun(@isempty, strfind(hdr.label, CHANNEL_NAMES)))
```

In a while loop use **ft_read_data** to get data:

```octave
data = ft_read_data(filename, 'begsample', begsample, 'endsample', endsampl, 'chanindx', My_channels, 'blocking', true, 'timeout', 5);
```

From here you can do whatever online analysis you want to do with the “data” variable.

### Step 3: Handle triggers

Once you have extracted the feature of interest you want this to trigger an event. This can be done in several ways. The best way probably depends on what feature you are extracting, what type of event you want to trigger and what stimuli presentation software you use.

Currently we have two solutions in the lab: Either sending triggers from Matlab to Presentation or sharing variables between separate instances of Matlab.


#### A) Send trigger to Presentation using TTL triggers

To get triggers from Matlab running your online data processing to Presentation running your paradigm, Matlab has to send a TTL trigger by an output port, which is then read by Presentation at a separate input port.

<p align="center">
  <img width="600" height="200" src="http://natmeg.se/____impro/1/onewebmedia/Presentation1_edited1.png?etag=W%2F%224ac1-57cda23f%22&sourceContentType=image%2Fpng&ignoreAspectRatio&resize=369%2B156&extract=0%2B0%2B368%2B156">
</p>

To send TTL triggers from Matlab include the following code at the start of your script to access the TTL (documentation for the functions are found here: http://apps.usd.edu/coglab/psyc770/IO64.html):

```octave
config_io;
adress = 41008;
outp(adress, 0);          % Reset port
```

When you want to send the trigger from Matlab you should make it execute the following code:

```octave
outp(adress, value);      % Send trigger
WaitSecs(0.004);          % Wait (this delay works)
outp(adress, 0);          % Reset port
```

This opens the port, sends the trigger with the code you specify in the variable value (must be an integer between 1-255), waits 4ms while sending the trigger and then close the port afterwards (i.e. sends a trigger with code "0").

To receive the trigger in Presentation you need to specify the input port under the input port menu. In the menu select port 5 (PCIe-6509). With this port you can read events as with any other port in Presentation.


#### B) Multiple Matlab instances

_NB! This option might not be able to send trigger to Acqusistion computer at NatMEG._

Matlab is not good at handling multiple processes at once - such as reading and processing data from buffer and delivering stimuli with precise timing. If real-time data have to trigger stimuli etc. this has to run in a separate instance of Matlab.

<p align="center">
  <img width="600" height="200" src="http://natmeg.se/____impro/1/onewebmedia/matlab_triggers_edited1.png?etag=W%2F%226a2a-57cda270%22&sourceContentType=image%2Fpng&ignoreAspectRatio&resize=370%2B139&extract=1%2B0%2B369%2B139">
</p>

Start two instances of Matlab; one running your script for reading and processing data, and another that runs your script for sending triggers. My solution is to create a Matlab file in memory that is continuously read by two independent instances of Matlab running on the same computer. This can easily be done by adding the script SetUpSharedFile.m (obtainable by request) to your directory and run the function SetUpSharedFile at the start of both of your Matlab script.

```octave
m = SetUpSharedFile(filename);
```

Where "filename" is the full filename (including path) to a .m file, e.g. "your_path/triggerFile.m". The variable m will be appearing as a struct in the Matlab workspaces. Whenever a trigger should be send you can change the value of the shared file, e.g.:

```octave
m.Data(1) = 2;      % Change value to 2
```

The change to the variable will be read by any other Matlab process that also has set up and access to the shared file. You can then make conditional loops in either script to send and respond to changes in the shared file.

## Troubleshooting

If the FieldTrip buffer was not closed correctly on the acquisition PC it might cause problems with reading data, the next time it is started. Be sure to close the buffer correctly by pressing **ctrl+c** and NOT by pressing the X in the corner of the terminal window.

If the buffer does not respond and stopping and restarting it does not work, you have to kill the buffer. This is not a nice thing to do, and you should not be in this situation to begin with. Open a new terminal on the acquisition PC. Type "netstat -tulpn". This gives list of processes running on the acquisition PC. Find the process named **neuromag2ft** with a port number like "0.0.0.0.0.1972". Read the PID of this process. Be completely sure that you read the right PID. Then write "kill <PID>" in the terminal, where <PID> is the number you read. This will brutally kill the buffer. Then a new instance can be started.


For questions about the real-time buffer see the see the FieldTrip webpage (http://www.fieldtriptoolbox.org/development/realtime/). For questions about the NatMEG implementation ask the NatMEG staff (http://natmeg.se/teamNatMEG/index.html).

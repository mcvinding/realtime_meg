scenario = "cue_tapping";
no_logfile = true;
default_background_color = 128,128,128;
default_font_size = 48;
default_text_color = 0,0,0;
active_buttons = 3;
button_codes = 1,2,64; 
write_codes = true;

begin;
wavefile { filename = "D:\\NATMEG PROJECTS\\20055_parkinson_motor\\Presentation\\Click_50ms-region-000.wav"; } fname;
sound { wavefile fname; } beep1;

trial {	
	picture {
	  text { caption = "Höger hand"; transparent_color = 128,128,128;};
	  x = 0; y = 0;
	} intro_txt;
} intro;

trial {
    trial_type = first_response;
    stimulus_event {
        picture {
				text { caption = "+"; transparent_color = 128,128,128;} txt1;
            x = 0; y = 0;
        };
        code = "Stim Event";
        target_button = 1;
    } my_event;
} fixation;

picture {
  text { caption = "Tack"; transparent_color = 128,128,128; };
  x = 0; y = 0;
} tack_txt;

#Begin PCL
begin_pcl;

	intro.present();

	# In/out ports
	term.print_line ("Initiating ports");
	output_port MEG_port = output_port_manager.get_port(1);
	input_port ttl_trigger = input_port_manager.get_port(1);
	wait_interval(500);

	# Initial variables
	int frequency = 2; 						## Tapping/cue frequency (in Hz)
	int duration_of_tapping_min = 3;
	int cue_interval_s = 5;					# number of sec with cues
	int cooldown = 30; 						# number of seconds after tapping cues where no input can be recieved
	int n_responses = 0;

	
	#  Prepare run
	int cuesInblock = frequency * cue_interval_s;
	int cue_ITI = 1000 / frequency;
	int tapping_interval_ms = duration_of_tapping_min * 60 * 1000;
	int cooldown_ms = cooldown * 1000;
	int cue_TTL_any = 4;		# Trigger for cue
	int cue_TTL_fin = 2;		# Trigger for last cue
	int cue_TTL_1st = 1;		# Trigger for first cue
	int TTL_done = 64;		# Trigger for end experiment.
	int TTL_left = 8;
	int TTL_right = 16;
	
	wait_interval(1000);

	# Play tapping cues subroutine
	sub play_cues (int nCues) begin
		loop int k = 1 until k > nCues begin
			if (k == 1) then
				MEG_port.send_code(cue_TTL_1st,10);
				term.print_line(cue_TTL_1st)
			elseif (k == cuesInblock) then
				MEG_port.send_code(cue_TTL_fin,10);
				term.print_line(cue_TTL_fin);
				term.print_line("Now tapping...")
			else
				MEG_port.send_code(cue_TTL_any,10);
				term.print_line(cue_TTL_any);
			end;
			
			beep1.present();
			wait_interval((cue_ITI));
			k = k+1
		end;
	end;

	# Run experiment...
	fixation.present();
	
	term.print("cooldown time = ");
	term.print_line(cooldown_ms);
	MEG_port.send_code(TTL_right,10);

	wait_interval(1000);
	play_cues(cuesInblock);
	cooldown = 0;
	n_responses = 0;
		
	# loop through all miliseconds in experiment
	loop int ms = 1 until ms > tapping_interval_ms begin
	
		if (response_manager.last_response( ) == 2 && response_manager.total_response_count(2) > n_responses) then;
			n_responses = n_responses+1;
			term.print("Manually cues started...");
			play_cues(cuesInblock);
			cooldown = 0;
		end;
		
		if (response_manager.last_response( ) == 1) then
			cooldown = 0;
			term.print_line("PAUSED");
		end;
		
		if (ttl_trigger.new_code_count() > 0 && cooldown > cooldown_ms) then
			int code = ttl_trigger.last_code();
			term.print("recieved trigger = ");
			term.print_line(code);
			play_cues(cuesInblock);
			cooldown = 0;
		else
			cooldown = cooldown+1;
			if (cooldown == cooldown_ms) then
				term.print_line("cooldown over!");
			end;
			
		end;
		
		wait_interval(1);
		ms = ms+1;	

		if (ms > tapping_interval_ms) then
			term.print_line("DONE TAPPING");
		end;
		
	end;
	
	MEG_port.send_code(TTL_done,10);
	tack_txt.present();
   system_keyboard.get_input();
	
	#end;

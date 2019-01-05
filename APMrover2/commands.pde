// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-

/* Functions in this file:
	void init_commands()
	struct Location get_cmd_with_index(int i)
	void set_cmd_with_index(struct Location temp, int i)
	void increment_cmd_index()
	void decrement_cmd_index()
	long read_alt_to_hold()
	void set_next_WP(struct Location *wp)
	void set_guided_WP(void)
	void init_home()
	void restart_nav()
************************************************************ 
*/

static void init_commands()
{
    g.command_index.set_and_save(0);
	nav_command_ID	= NO_COMMAND;
	non_nav_command_ID	= NO_COMMAND;
}

// Getters
// -------
static struct Location get_cmd_with_index(int i)
{
	struct Location temp;
	uint16_t mem;

	// Find out proper location in memory by using the start_byte position + the index
	// --------------------------------------------------------------------------------
	if (i > g.command_total) {
		memset(&temp, 0, sizeof(temp));
		temp.id = CMD_BLANK;
	}else{
		// read WP position
		mem = (WP_START_BYTE) + (i * WP_SIZE);
		temp.id = hal.storage->read_byte(mem);

		mem++;
		temp.options = hal.storage->read_byte(mem);

		mem++;
		temp.p1 = hal.storage->read_byte(mem);

		mem++;
		temp.alt = (long)hal.storage->read_dword(mem);

		mem += 4;
		temp.lat = (long)hal.storage->read_dword(mem);

		mem += 4;
		temp.lng = (long)hal.storage->read_dword(mem);
	}

	// Add on home altitude if we are a nav command (or other command with altitude) and stored alt is relative
	if((temp.id < MAV_CMD_NAV_LAST || temp.id == MAV_CMD_CONDITION_CHANGE_ALT) && temp.options & MASK_OPTIONS_RELATIVE_ALT){
		temp.alt += home.alt;
	}

	return temp;
}

// Setters
// -------
static void set_cmd_with_index(struct Location temp, int i)
{
	i = constrain_int16(i, 0, g.command_total.get());
	uint16_t mem = WP_START_BYTE + (i * WP_SIZE);

	// Set altitude options bitmask
	// XXX What is this trying to do?
	if ((temp.options & MASK_OPTIONS_RELATIVE_ALT) && i != 0){
		temp.options = MASK_OPTIONS_RELATIVE_ALT;
	} else {
		temp.options = 0;
	}

	hal.storage->write_byte(mem, temp.id);

    mem++;
	hal.storage->write_byte(mem, temp.options);

	mem++;
	hal.storage->write_byte(mem, temp.p1);

	mem++;
	hal.storage->write_dword(mem, temp.alt);

	mem += 4;
	hal.storage->write_dword(mem, temp.lat);

	mem += 4;
	hal.storage->write_dword(mem, temp.lng);
}

// run this at setup on the ground
// -------------------------------
void init_home()
{
    if (!have_position) {
        // we need position information
        return;
    }

	gcs_send_text_P(SEVERITY_LOW, PSTR("init home"));

	home.id 	= MAV_CMD_NAV_WAYPOINT;

	home.lng 	= g_gps->longitude;				// Lon * 10**7
	home.lat 	= g_gps->latitude;				// Lat * 10**7
    gps_base_alt    = max(g_gps->altitude_cm, 0);
    home.alt        = g_gps->altitude_cm;
	home_is_set = true;

	// Save Home to EEPROM - Command 0
	// -------------------
	set_cmd_with_index(home, 0);
}

static void restart_nav()
{
    nav_command_ID = NO_COMMAND;
    nav_command_index = 0;
    process_next_command();
}

/********************************************************************************/
// Command Event Handlers
/********************************************************************************/

static void
handle_process_condition_command()
{
	gcs_send_text_fmt(PSTR("Executing command ID #%i"),next_nonnav_command.id);
	switch(next_nonnav_command.id){

		case MAV_CMD_CONDITION_DELAY:
			do_wait_delay();
			break;

		default:
			break;
	}
}

static void handle_process_do_command()
{
	gcs_send_text_fmt(PSTR("Executing command ID #%i"),next_nonnav_command.id);
	switch(next_nonnav_command.id){

		case MAV_CMD_DO_SET_SERVO:
			do_set_servo();
			break;

		case MAV_CMD_DO_SET_RELAY:
			do_set_relay();
			break;

		case MAV_CMD_DO_REPEAT_SERVO:
			do_repeat_servo();
			break;

		case MAV_CMD_DO_REPEAT_RELAY:
			do_repeat_relay();
			break;

	}
}

static void handle_no_commands()
{      
	gcs_send_text_fmt(PSTR("No commands - setting HOLD"));
    set_mode(HOLD);
}

/********************************************************************************/
//  Condition (May) commands
/********************************************************************************/

static void do_wait_delay()
{
	condition_start = millis();
	condition_value  = next_nonnav_command.lat * 1000;	// convert to milliseconds
}

/********************************************************************************/
//  Do (Now) commands
/********************************************************************************/

static void do_set_servo()
{
    hal.rcout->enable_ch(next_nonnav_command.p1 - 1);
    hal.rcout->write(next_nonnav_command.p1 - 1, next_nonnav_command.alt);
}

static void do_set_relay()
{
	if (next_nonnav_command.p1 == 1) {
		relay.on();
	} else if (next_nonnav_command.p1 == 0) {
		relay.off();
	}else{
		relay.toggle();
	}
}

static void do_repeat_servo()
{
	event_id = next_nonnav_command.p1 - 1;

	if(next_nonnav_command.p1 >= CH_5 + 1 && next_nonnav_command.p1 <= CH_8 + 1) {
		event_timer 	= 0;
		event_delay 	= next_nonnav_command.lng * 500.0;	// /2 (half cycle time) * 1000 (convert to milliseconds)
		event_repeat 	= next_nonnav_command.lat * 2;
		event_value 	= next_nonnav_command.alt;
        event_undo_value  = RC_Channel::rc_channel(next_nonnav_command.p1-1)->radio_trim;
		update_events();
	}
}

static void do_repeat_relay()
{
	event_id 		= RELAY_TOGGLE;
	event_timer 	= 0;
	event_delay 	= next_nonnav_command.lat * 500.0;	// /2 (half cycle time) * 1000 (convert to milliseconds)
	event_repeat	= next_nonnav_command.alt * 2;
	update_events();
}

// For changing active command mid-mission
//----------------------------------------
static void change_command(uint8_t cmd_index)
{
	struct Location temp = get_cmd_with_index(cmd_index);

	if (temp.id > MAV_CMD_NAV_LAST ){
		gcs_send_text_P(SEVERITY_LOW,PSTR("Bad Request - cannot change to non-Nav cmd"));
	} else {
		gcs_send_text_fmt(PSTR("Received Request - jump to command #%i"),cmd_index);

		nav_command_ID		= NO_COMMAND;
		next_nav_command.id = NO_COMMAND;
		non_nav_command_ID 	= NO_COMMAND;

		nav_command_index 	= cmd_index - 1;
		g.command_index.set_and_save(cmd_index);
		update_commands();
	}
}

// called by 10 Hz loop
// --------------------
static void update_commands(void)
{
	if(control_mode == AUTO){
		if(home_is_set == true && g.command_total > 1){
		process_next_command();
		}
	}									// Other (eg GCS_Auto) modes may be implemented here
}

static void process_next_command()
{
	// This function makes sure that we always have a current navigation command
	// and loads conditional or immediate commands if applicable

	struct Location temp;
	uint8_t old_index = 0;

	// these are Navigation/Must commands
	// ---------------------------------
	if (nav_command_ID == NO_COMMAND){ // no current navigation command loaded
		old_index = nav_command_index;
		temp.id = MAV_CMD_NAV_LAST;
		while(temp.id >= MAV_CMD_NAV_LAST && nav_command_index <= g.command_total) {
			nav_command_index++;
			temp = get_cmd_with_index(nav_command_index);
		}

		gcs_send_text_fmt(PSTR("Nav command index updated to #%i"),nav_command_index);

		if(nav_command_index > g.command_total){
            handle_no_commands();
		} else {
			next_nav_command = temp;
			nav_command_ID = next_nav_command.id;
			non_nav_command_index = NO_COMMAND;			// This will cause the next intervening non-nav command (if any) to be loaded
			non_nav_command_ID = NO_COMMAND;

			process_nav_cmd();
		}
	}

	// these are Condition/May and Do/Now commands
	// -------------------------------------------
	if (non_nav_command_index == NO_COMMAND) {		// If the index is NO_COMMAND then we have just loaded a nav command
		non_nav_command_index = old_index + 1;
		//gcs_send_text_fmt(PSTR("Non-Nav command index #%i"),non_nav_command_index);
	} else if (non_nav_command_ID == NO_COMMAND) {	// If the ID is NO_COMMAND then we have just completed a non-nav command
		non_nav_command_index++;
	}

		//gcs_send_text_fmt(PSTR("Nav command index #%i"),nav_command_index);
		//gcs_send_text_fmt(PSTR("Non-Nav command index #%i"),non_nav_command_index);
		//gcs_send_text_fmt(PSTR("Non-Nav command ID #%i"),non_nav_command_ID);
	if(nav_command_index <= (int)g.command_total && non_nav_command_ID == NO_COMMAND) {
		temp = get_cmd_with_index(non_nav_command_index);
		if(temp.id <= MAV_CMD_NAV_LAST) {		// The next command is a nav command.  No non-nav commands to do
			g.command_index.set_and_save(nav_command_index);
			non_nav_command_index = nav_command_index;
			non_nav_command_ID = WAIT_COMMAND;
			gcs_send_text_fmt(PSTR("Non-Nav command ID updated to #%i"),non_nav_command_ID);

		} else {								// The next command is a non-nav command.  Prepare to execute it.
			g.command_index.set_and_save(non_nav_command_index);
			next_nonnav_command = temp;
			non_nav_command_ID = next_nonnav_command.id;
			gcs_send_text_fmt(PSTR("Non-Nav command ID updated to #%i"),non_nav_command_ID);

			process_non_nav_command();
		}

	}
}

/**************************************************/
//  These functions implement the commands.
/**************************************************/
static void process_nav_cmd()
{
	//gcs_send_text_P(SEVERITY_LOW,PSTR("New nav command loaded"));

	// clear non-nav command ID and index
	non_nav_command_index	= NO_COMMAND;		// Redundant - remove?
	non_nav_command_ID		= NO_COMMAND;		// Redundant - remove?

}

static void process_non_nav_command()
{
	//gcs_send_text_P(SEVERITY_LOW,PSTR("new non-nav command loaded"));

	if(non_nav_command_ID < MAV_CMD_CONDITION_LAST) {
		handle_process_condition_command();
	} else {
		handle_process_do_command();
		// flag command ID so a new one is loaded
		// -----------------------------------------
		non_nav_command_ID = NO_COMMAND;
	}
}



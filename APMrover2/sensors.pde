// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-

/*
  read and update the battery
 */
static void read_battery(void)
{
	if(g.battery_monitoring == 0) {
		battery_voltage1 = 0;
		return;
	}
	
    if(g.battery_monitoring == 3 || g.battery_monitoring == 4) {
        // this copes with changing the pin at runtime
        batt_volt_pin->set_pin(g.battery_volt_pin);
        battery_voltage1 = BATTERY_VOLTAGE(batt_volt_pin);
    }

    if (g.battery_monitoring == 4) {
        static uint32_t last_time_ms;
        uint32_t tnow = hal.scheduler->millis();
        float dt = tnow - last_time_ms;
        if (last_time_ms != 0 && dt < 2000) {
            // this copes with changing the pin at runtime
            batt_curr_pin->set_pin(g.battery_curr_pin);
            current_amps1    = CURRENT_AMPS(batt_curr_pin);
            // .0002778 is 1/3600 (conversion to hours)
            current_total1   += current_amps1 * dt * 0.0002778f; 
        }
        last_time_ms = tnow;
    }
}


// read the receiver RSSI as an 8 bit number for MAVLink
// RC_CHANNELS_SCALED message
void read_receiver_rssi(void)
{
    rssi_analog_source->set_pin(g.rssi_pin);
    float ret = rssi_analog_source->voltage_average() * 50;
    receiver_rssi = constrain_int16(ret, 0, 255);
}

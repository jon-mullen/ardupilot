// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-

// This file is just a placeholder for your configuration file.  If you wish to change any of the setup parameters from
// their default values, place the appropriate #define statements here.


#define MODE_CHANNEL        6

#define MODE_1              HOLD
#define MODE_2              HOLD
#define MODE_3              MANUAL
#define MODE_4              MANUAL
#define MODE_5              AUTO
#define MODE_6              AUTO

// steering constants
#define STEER_MIN_PWM       1185
#define STEER_MAX_PWM       1859

#define STEER_LOW           STEER_MIN_PWM + 0.3333333 * (STEER_MAX_PWM - STEER_MIN_PWM)
#define STEER_HIGH          STEER_MIN_PWM + 0.6666666 * (STEER_MAX_PWM - STEER_MIN_PWM)

#define STEER_RELAY_1       1
#define STEER_RELAY_2       2

#define STEER_RELAY_OPEN    1
#define STEER_RELAY_CLOSED  0

// throttle constants
#define THR_MIN_PWM         1126
#define THR_MAX_PWM         1915
#define THR_MIDDLE          (THR_MIN_PWM + THR_MAX_PWM) / 2

#define THR_RELAY_1         4
#define THR_RELAY_2         5

#define THR_RELAY_OPEN      1
#define THR_RELAY_CLOSED    0

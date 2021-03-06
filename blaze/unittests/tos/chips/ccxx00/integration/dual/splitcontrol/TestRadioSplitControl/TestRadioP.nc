
#include "TestCase.h"

/**
 * @author David Moss
 */
module TestRadioP {
  uses {
    interface TestControl as SetUp;
    
    interface TestCase as TestRadioPowerCycle;
    interface TestCase as TestAlreadyOn;
    interface TestCase as TestAlreadyOff;
    interface TestCase as TestAlreadyTurningOn;
    interface TestCase as TestAlreadyTurningOff;
    
    interface SplitControl;
    interface AMSend;
    interface Receive;
    interface Timer<TMilli>;
    interface State;
    interface Leds;
  }
}

implementation {

  uint16_t myIndex;
  
  /** TRUE if the radio is on */
  bool on;
  
  enum {
    S_IDLE,
    S_SETUP,
    S_TESTRADIOPOWERCYCLE,
    S_TESTALREADYON,
    S_TESTALREADYOFF,
    S_TESTALREADYTURNINGON,
    S_TESTALREADYTURNINGOFF,
  };
  
    
  enum {
    RADIO_POWER_CYCLES = 1000,
  };

  /***************** Prototypes ****************/
  task void testAlreadyTurningOn_finish();
  task void testAlreadyTurningOff_finish();
   
  /***************** SetUp Events ****************/
  event void SetUp.run() {
    call State.forceState(S_SETUP);
    if(call SplitControl.stop() != SUCCESS) {
      call SetUp.done();
    }
  }
  
  
  /***************** Tests ****************/
  /**
   * Turn the radio on and off RADIO_POWER_CYCLES times, verify we don't lock 
   * up or have any problems with SplitControl
   */
  event void TestRadioPowerCycle.run() {
    call State.forceState(S_TESTRADIOPOWERCYCLE);
    myIndex = 0;
    if(call SplitControl.start() != SUCCESS) {
      assertFail("start() failed");
      call TestRadioPowerCycle.done();
    }
  }
  
  event void TestAlreadyOn.run() {
    assertSuccess();
    call State.forceState(S_TESTALREADYON);
    if(call SplitControl.start() != SUCCESS) {
      assertFail("start() failed");
      call TestAlreadyOn.done();
    }
  }
  
  event void TestAlreadyOff.run() {
    call State.forceState(S_TESTALREADYOFF);
    assertEquals("stop() didn't return EALREADY", EALREADY, call SplitControl.stop());
    call TestAlreadyOff.done();
  }
  
  event void TestAlreadyTurningOn.run() {
    call State.forceState(S_TESTALREADYTURNINGON);
    if(call SplitControl.start() != SUCCESS) {
      assertFail("start() failed");
      call TestAlreadyOn.done();
    }
    
    if(!on) {
      // SplitControl.startDone() hasn't signaled yet
      // The radio stack doesn't follow the SplitControl TEP only because
      // it takes extra memory footprint to do so.
      assertEquals("restart() wasn't EALREADY", EALREADY, call SplitControl.start());
      assertEquals("stop() wasn't EALREADY", EALREADY, call SplitControl.stop());
    } else {
      // There's no way for this to fail since the call wasn't split phase
      assertSuccess();
    }
  }
  
  event void TestAlreadyTurningOff.run() {
    call State.forceState(S_TESTALREADYTURNINGOFF);
    if(call SplitControl.start() != SUCCESS) {
      assertFail("start() failed");
      call TestAlreadyTurningOff.done();
    }
  }
  
  
    
  /***************** SplitControl Events ****************/
  event void SplitControl.startDone(error_t error) {
    call Leds.led2On();
    on = TRUE;
    
    
    switch(call State.getState()) {
    case S_TESTRADIOPOWERCYCLE:
      if(error != SUCCESS) {
        // Do it like this so we don't generate a lot of assertions
        assertEquals("startDone([error])", SUCCESS, error);
      }
      
      if(call SplitControl.stop() != SUCCESS) {
        assertFail("stop() failed");
        call TestRadioPowerCycle.done();
      }
      break;
      
    case S_TESTALREADYON:
      if(error != SUCCESS) {
        assertEquals("startDone([error])", SUCCESS, error);
      }
      
      assertEquals("restart() wasn't EALREADY", EALREADY, call SplitControl.start());
      call TestAlreadyOn.done();
      break;
    
    case S_TESTALREADYTURNINGON:
      post testAlreadyTurningOn_finish();
      break;
    
    case S_TESTALREADYTURNINGOFF:
      if(call SplitControl.stop() != SUCCESS) {
        assertFail("stop() failed");
        call TestAlreadyTurningOff.done();
      
      } else {
        if(on) {
          // SplitControl.stopDone hasn't signaled yet
          assertEquals("start() wasn't EBUSY", EBUSY, call SplitControl.start());
          assertEquals("stop() wasn't SUCCESS", SUCCESS, call SplitControl.stop());
          
        } else {
          // There's no way for this to fail since the call wasn't split phase
          assertSuccess();
          call TestAlreadyTurningOff.done();
        }
        
      }
      break;
      
    default:
    }
  }
  
  event void SplitControl.stopDone(error_t error) {
    call Leds.led2Off();
    on = FALSE;
    
    switch(call State.getState()) {
    case S_SETUP:
      call State.toIdle();
      call SetUp.done();
      break;
    
    case S_TESTRADIOPOWERCYCLE:
      myIndex++;
      if(error != SUCCESS) {
        // Do it like this so we don't generate a lot of assertions
        assertEquals("stopDone([error])", SUCCESS, error);
      }
      
      if(myIndex < RADIO_POWER_CYCLES) {
        if(call SplitControl.start() != SUCCESS) {
          assertFail("restart() failed");
          call TestRadioPowerCycle.done();
        }
        
      } else {
        assertEquals("Too few cycles", RADIO_POWER_CYCLES, myIndex);
        call TestRadioPowerCycle.done();
      }
      break;
    
    case S_TESTALREADYTURNINGOFF:
      post testAlreadyTurningOff_finish();
      break;
      
    default:
    }
  }
  
  /***************** AMSend Events ****************/
  event void AMSend.sendDone(message_t *msg, error_t error) {
  }
  
  /***************** Receive Events ****************/
  event message_t *Receive.receive(message_t *msg, void *payload, uint8_t len) {
   return msg;
  }
  
  /***************** Timer Events ****************/
  event void Timer.fired() {
  }
  
  /***************** Tasks ****************/
  task void testAlreadyTurningOn_finish() {
    call TestAlreadyTurningOn.done();
  }
  
  task void testAlreadyTurningOff_finish() {
    call TestAlreadyTurningOff.done();
  }
  
  
}

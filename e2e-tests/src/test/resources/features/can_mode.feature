# language: en
Feature: OBD CAN Multiplexing Mode

  @cuatro
  Scenario: Setting NORMAL mode configures FDCAN2 pins (if branch)
    When control write:
      """
      SetCanMode: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioBModer: 256911360L    # PB5/6→alt(2), PB10/11→out(1), PB12/13→analog(3)
          gpioBPupdr: 0L           # PB5/6/12/13 → PULL_NONE
          gpioBOdr: 2048L          # PB11 CAN4 disabled, PB10 CAN2 re-enabled
        }
      }
      """

  @cuatro
  Scenario: Setting OBD_CAN2 mode configures FDCAN2 pins (else branch)
    When control write:
      """
      SetCanMode: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioBModer: 173030400L   # PB5/6→analog(3), PB10/11→out(1), PB12/13→alt(2)
          gpioBPupdr: 0L
          gpioBOdr: 1024L          # PB10 CAN2 disabled, PB11 CAN4 re-enabled
        }
      }
      """

  @tres
  Scenario: Setting NORMAL mode on tres (same GPIOB as cuatro for CAN2/4)
    When control write:
      """
      SetCanMode: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioBModer: 256911360L
          gpioBOdr: 2048L
        }
      }
      """

  @red
  Scenario: Setting NORMAL mode on red uses PB3/4 for CAN2/4
    When control write:
      """
      SetCanMode: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioBModer: 251668800L   # PB3/4→out(1), PB5/6→alt(2), PB12/13→analog(3)
          gpioBOdr: 16L            # PB4 CAN4 disabled, PB3 CAN2 re-enabled
        }
      }
      """

  @red
  Scenario: Setting OBD_CAN2 mode on red (else branch)
    When control write:
      """
      SetCanMode: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioBModer: 167787840L   # PB3/4→out(1), PB5/6→analog(3), PB12/13→alt(2)
          gpioBOdr: 8L             # PB3 CAN2 disabled, PB4 CAN4 re-enabled
        }
      }
      """

  Scenario: Setting NORMAL mode with non-1 param1 value
    When control write:
      """
      SetCanMode: {
        param1: 2
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioBModer: 256911360L    # same as param1=0: PB5/6→alt(2), PB10/11→out(1), PB12/13→analog(3)
          gpioBPupdr: 0L
          gpioBOdr: 2048L          # PB11 CAN4 disabled, PB10 CAN2 re-enabled
        }
      }
      """

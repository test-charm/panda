# language: en
@body
Feature: Body Firmware DotStar LED Driver

  Scenario: B10 — dotstar_init at startup and dotstar_fill sets all pixels to a color
    Then body control data should be:
      """
      dotstar: {
        initialized: true
        brightness: 31
      }
      """
    When dotstar fill: r = 100, g = 150, b = 200
    When dotstar show
    Then body control data should be:
      """
      dotstar: {
        pixel0R: 100
        pixel0G: 150
        pixel0B: 200
        pixel9R: 100
        pixel9G: 150
        pixel9B: 200
      }
      """

  Scenario: B10b — dotstar_set_pixel writes a single LED without affecting others
    When dotstar fill: r = 0, g = 0, b = 0
    When dotstar set pixel: index = 3, r = 255, g = 128, b = 64
    Then body control data should be:
      """
      dotstar: {
        pixel3R: 255
        pixel3G: 128
        pixel3B: 64
        pixel0R: 0
        pixel0G: 0
        pixel0B: 0
      }
      """

  Scenario: B10c — dotstar_set_global_brightness clamps to max 31
    When dotstar set global brightness: 50
    Then body control data should be:
      """
      dotstar.brightness: 31
      """

  Scenario: B11 — dotstar_run_rainbow produces correct pixel colors and breathing brightness
    When dotstar run rainbow: now_us = 500000
    When dotstar show
    Then body control data should be:
      """
      dotstar: {
        pixel0R: 205
        pixel0G: 50
        pixel0B: 0
        brightness: 13
      }
      """

  Scenario: B12 — dotstar_apply_breathe scales pixel color by triangular wave phase
    When dotstar apply breathe: r = 100, g = 150, b = 200, now_us = 250000, cycle_us = 1000000
    Then body control data should be:
      """
      dotstar: {
        pixel0R: 49
        pixel0G: 74
        pixel0B: 99
      }
      """

  Scenario: B12b — dotstar_apply_breathe with cycle_us=0 uses full brightness
    When dotstar apply breathe: r = 50, g = 100, b = 150, now_us = 0, cycle_us = 0
    Then body control data should be:
      """
      dotstar: {
        brightness: 31
        pixel0R: 50
        pixel0G: 100
        pixel0B: 150
      }
      """

--[[----------------------------------------------------------------------------
-- Duplex.MIDI-Fighter-Twister
----------------------------------------------------------------------------]]--

duplex_configurations:insert {
  -- configuration properties
  name = "Mix twins",
  pinned = true,

  -- device properties
  device = {
    --class_name = "",          
    device_port_in = "",
    device_port_out = "",
    thumbnail = "Controllers/MIDI-Fighter-Twister/Thumbnail.bmp",
    display_name = "MIDI-Fighter Twister",
    control_map = "Controllers/MIDI-Fighter-Twister/Controlmaps/MF_Twister_twins.xml",
    protocol = DEVICE_PROTOCOL.MIDI
  },
  
  applications = {
    TrackSelector = {
      mappings = {
        next_page = {
          group_name = "RightButtons",
          index = 2
        },
        prev_page = {
          group_name = "LeftButtons",
          index = 2
        },
      },
      options = {
        page_size = 8
      }
    },

    Effect = {
      mappings = {
        parameters = {
          group_name = "Encoders",
        },
        param_active = {
          group_name = "EncodersStatus"
        },
        device_select = {
          group_name = "FxSelector",
          index = 1,
        },
        param_next = {
          group_name = "RightButtons",
          index = 1
        },
        param_prev = {
          group_name = "LeftButtons",
          index = 1
        }
      },
    },

    Mixer = {
      mappings = {
        levels = {
          group_name = "Level"
        },
        panning = {
          group_name = "Pan"
        },
        mute = {
          group_name = "Mute"
        },
        solo = {
          group_name = "Solo"
        },
      },
      options = {
        invert_mute = 1,
        follow_track = 1,
        page_size = 8,
      }
    }
  }
}

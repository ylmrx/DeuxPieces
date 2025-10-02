--[[============================================================================
-- Duplex.RoamingDSP
============================================================================]]--

--[[--

Extend this class for 'roaming' control of a DSP device 

]]--

----------------------------------------------------------------------------]]--

class 'RoamingDSP' (Automateable)

RoamingDSP.FOLLOW_POS_ENABLED = 1
RoamingDSP.FOLLOW_POS_DISABLED = 2
RoamingDSP.LOCKED_ENABLED = 1
RoamingDSP.LOCKED_DISABLED = 2
RoamingDSP.RECORD_NONE = 1 -- No recording
RoamingDSP.RECORD_TOUCH = 2 -- Record when touched
RoamingDSP.RECORD_LATCH = 3 -- Record once touched

---  Options
-- @field locked Enable/Disable locking
-- @field record_method Determine how to record automation
-- @field follow_pos Follow the selected device in the DSP chain
-- @table default_options
RoamingDSP.default_options = {
  locked = {
    label = "Lock to device",
    description = "Disable locking if you want the controls to"
                .."\nfollow the currently selected device ",
    on_change = function(app)
      if (app.options.locked.value == RoamingDSP.LOCKED_DISABLED) then
        app:clear_device()
        app.current_device_requested = true
      end
      app:tag_device(app.target_device)
    end,
    items = {
      "Lock to device",
      "Roam freely"
    },
    value = 2,
  },
  follow_pos = {
    label = "Follow pos",
    description = "Follow the selected device in the DSP chain",
    items = {
      "Enabled",
      "Disabled"
    },
    value = 1,
  },

}

---  Mappings
-- @field lock_button control the locked state of the selected device
-- @field next_device used for locating a device across tracks
-- @field prev_device used for locating a device across tracks
-- @table available_mappings
RoamingDSP.available_mappings = {
  lock_button = {
    description = "RoamingDSP: Lock/unlock device",
  },
  next_device = {
    description = "RoamingDSP: Next device",
  },
  prev_device = {
    description = "RoamingDSP: Previous device",
  },


}

RoamingDSP.default_palette = {
  lock_on           = { color = {0xFF,0xFF,0xFF}, text = "♥", val=true  },
  lock_off          = { color = {0x00,0x00,0x00}, text = "♥", val=false },
  prev_device_on    = { color = {0xFF,0xFF,0xFF}, text = "◄", val=true  },
  prev_device_off   = { color = {0x00,0x00,0x00}, text = "◄", val=false },
  next_device_on    = { color = {0xFF,0xFF,0xFF}, text = "►", val=true  },
  next_device_off   = { color = {0x00,0x00,0x00}, text = "►", val=false },
}

Application.copy_properties(Automateable,RoamingDSP)

--------------------------------------------------------------------------------
--  merge superclass options, mappings & palette --

for k,v in pairs(Automateable.default_options) do
  RoamingDSP.default_options[k] = v
end
for k,v in pairs(Automateable.available_mappings) do
  RoamingDSP.available_mappings[k] = v
end
for k,v in pairs(Automateable.default_palette) do
  RoamingDSP.default_palette[k] = v
end

--------------------------------------------------------------------------------

--- Constructor method
-- @param (VarArg), see Application/Automateable to learn more

function RoamingDSP:__init(...)
  TRACE("RoamingDSP:__init()")

  -- the various UIComponents
  self._controls = {}
  --self._controls.lock_button = nil   -- UIButton
  --self._controls.prev_button = nil   -- UIButton
  --self._controls.next_button = nil   -- UIButton

  --- (renoise.AudioDevice) the device we are currently controlling
  self.target_device = nil

  --- (bool) current blink-state (lock button)
  self._blink = false

  --- (int) the target track index
  self.track_index = nil

  --- (int) the target device index 
  self.device_index = nil

  --- (bool), set when we should attempt to attach to 
  -- the current device (althought we might not succeed)
  self.current_device_requested = false

  --- (table) list of observable parameters
  self._parameter_observables = table.create()

    --- (table) list of observable device parameters
  self._device_observables = table.create()

  Automateable.__init(self,...)

  -- determine stuff after options have been applied

end

--------------------------------------------------------------------------------
-- @see Duplex.Application.start_app
-- @return bool or nil

function RoamingDSP:start_app()
  TRACE("RoamingDSP:start_app()")

  if not self._instance_name then
    local msg = "Could not start instance of Duplex RoamingDSP:"
              .."\nthe required property 'self._instance_name' has not"
              .."\nbeen specified, the application has been halted"
    renoise.app():show_warning(msg)
    return false
  end

  if not Application.start_app(self) then
    return false
  end

  self:initial_select()

end

--------------------------------------------------------------------------------
-- Initial select, performed on application start: 
-- if not in locked mode: use the currently focused track->device
-- if we are in locked mode: recognize any locked devices, but fall back
--  to the focused track->device if no locked device was found

function RoamingDSP:initial_select()
  TRACE("RoamingDSP:initial_select()")

  local device,track_idx,device_idx
  local search = self:do_device_search()
  if search then
    device = search.device
    track_idx = search.track_index
    device_idx = search.device_index
  else
    -- we failed to match a locked device,
    -- perform a 'soft' unlock
    self.options.locked.value = RoamingDSP.LOCKED_DISABLED
    self:update_lock_button()
  end
  if not device then
    device = rns.selected_device
    track_idx = rns.selected_track_index
    device_idx = rns.selected_device_index
  end

  if self:device_is_valid(device) then
    local skip_tag = true
    self:goto_device(track_idx,device_idx,device,skip_tag)
  end
  self:update_prev_next(track_idx,device_idx)

end

--------------------------------------------------------------------------------
-- Goto previous device
-- search from locked device (if available), otherwise use the selected device
-- @return bool

function RoamingDSP:goto_previous_device()
  TRACE("RoamingDSP:goto_previous_device()")

  local track_index,device_index
  if self.target_device then
    track_index = self.track_index
    device_index = self.device_index
  else
    track_index = rns.selected_track_index
    device_index = rns.selected_device_index
  end

  local search = self:search_previous_device(track_index,device_index)
  if search then
    self:goto_device(search.track_index,search.device_index,search.device)
  end
  self:follow_device_pos()
  return search and true or false

end

--------------------------------------------------------------------------------
-- Goto next device
-- search from locked device (if available), otherwise use the selected device
-- @return bool

function RoamingDSP:goto_next_device()
  TRACE("RoamingDSP:goto_next_device()")

  local track_index,device_index
  if self.target_device then
    track_index = self.track_index
    device_index = self.device_index
  else
    track_index = rns.selected_track_index
    device_index = rns.selected_device_index
  end
  local search = self:search_next_device(track_index,device_index)
  if search then
    self:goto_device(search.track_index,search.device_index,search.device)
  end
  self:follow_device_pos()
  return search and true or false

end


--------------------------------------------------------------------------------
-- Locate the prior device
-- @param track_index (int) start search from here
-- @param device_index (int) start search from here
-- @return table or nil

function RoamingDSP:search_previous_device(track_index,device_index)
  TRACE("RoamingDSP:search_previous_device()",track_index,device_index)

  local matched = nil
  local locked = (self.options.locked.value == RoamingDSP.LOCKED_ENABLED)
  local display_name = self:get_unique_name()
  for track_idx,v in ripairs(rns.tracks) do
    local include_track = true
    if track_index and (track_idx>track_index) then
      include_track = false
    end
    if include_track then
      for device_idx,device in ripairs(v.devices) do
        local include_device = true
        if device_index and (device_idx>=device_index) then
          include_device = false
        end
        if include_device then
          local search = {
            track_index=track_idx,
            device_index=device_idx,
            device=device
          }
          if locked and (device.display_name == display_name) then
            return search
          elseif self:device_is_valid(device) then
            return search
          end
        end

      end

    end

    if device_index and include_track then
      device_index = nil
    end

  end

end

--------------------------------------------------------------------------------
-- Locate the next device
-- @param track_index (int) start search from here
-- @param device_index (int) start search from here
-- @return table or nil

function RoamingDSP:search_next_device(track_index,device_index)
  TRACE("RoamingDSP:search_next_device()",track_index,device_index)

  local matched = nil
  local locked = (self.options.locked.value == RoamingDSP.LOCKED_ENABLED)
  local display_name = self:get_unique_name()
  for track_idx,v in ipairs(rns.tracks) do
    local include_track = true
    if track_index and (track_idx<track_index) then
      include_track = false
    end
    if include_track then
      for device_idx,device in ipairs(v.devices) do
        local include_device = true
        if device_index and (device_idx<=device_index) then
          include_device = false
        end
        if include_device then
          local search = {
            track_index=track_idx,
            device_index=device_idx,
            device=device
          }
          if locked and (device.display_name == display_name) then
            return search
          elseif self:device_is_valid(device) then
            return search
          end
        end
      end

    end

    if device_index and include_track then
      device_index = nil
    end

  end

end

--------------------------------------------------------------------------------
-- Attach to a device, transferring the 'tag' if needed
-- this is the final step of a "previous/next device" operation,
-- or called during the initial search
-- @param track_index (int) start search from here
-- @param device_index (int) start search from here
-- @param device (renoise.AudioDevice)
-- @param skip_tag (bool) don't tag device

function RoamingDSP:goto_device(track_index,device_index,device,skip_tag)
  TRACE("RoamingDSP:goto_device()",track_index,device_index,device,skip_tag)
  
  self:attach_to_device(track_index,device_index,device)

  if not skip_tag and 
    (self.options.locked.value == RoamingDSP.LOCKED_ENABLED) 
  then
    self:tag_device(device)
  end
  self:update_prev_next(track_index,device_index)

end


--------------------------------------------------------------------------------
-- Update the lit state of the previous/next device buttons
-- @param track_index (int) 
-- @param device_index (int) 

function RoamingDSP:update_prev_next(track_index,device_index)

  -- use locked device if available
  if (self.options.locked.value == RoamingDSP.LOCKED_ENABLED) then
    track_index = self.track_index
    device_index = self.device_index
  end

  if self._controls.prev_button then
    local prev_search = self:search_previous_device(track_index,device_index)
    local prev_state = (prev_search) and true or false
    if prev_state then
      self._controls.prev_button:set(self.palette.prev_device_on)
    else
      self._controls.prev_button:set(self.palette.prev_device_off)
    end
  end
  if self._controls.next_button then
    local next_search = self:search_next_device(track_index,device_index)
    local next_state = (next_search) and true or false
    if next_state then
      self._controls.next_button:set(self.palette.next_device_on)
    else
      self._controls.next_button:set(self.palette.next_device_off)
    end
  end

end


--------------------------------------------------------------------------------
-- Look for a device that match the provided name
-- it is called right after the target device has been removed,
-- or by initial_select()

function RoamingDSP:do_device_search()

  local display_name = self:get_unique_name()
  local device_count = 0
  for track_idx,track in ipairs(rns.tracks) do
    for device_idx,device in ipairs(track.devices) do
      if self:device_is_valid(device) and 
        (device.display_name == display_name) 
      then
        return {
          device=device,
          track_index=track_idx,
          device_index=device_idx
        }
      end
    end
  end

end


--------------------------------------------------------------------------------
-- Get the unique name of the device, as specified in options
-- @return string

function RoamingDSP:get_unique_name()
  
  local dev_name = self._process.browser._device_name
  local cfg_name = self._process.browser._configuration_name
  local app_name = self._app_name
  local inst = self._instance_name

  -- a nice trick: adding the instance name at the end will show the device 
  -- using the standard name (our extra information will be hidden)
  local unique_name = ("%s_%s_%s:%s"):format(dev_name,cfg_name,app_name,inst)
  return unique_name
  
end

--------------------------------------------------------------------------------
-- Test if the device is a valid target 
-- @param device (renoise.AudioDevice)
-- @return bool

function RoamingDSP:device_is_valid(device)

  TRACE("RoamingDSP:device_is_valid(device)",device,"instance_name",self._instance_name)

  if device and (device.name == self._instance_name) then
    return true
  else
    return false
  end
end

--------------------------------------------------------------------------------
-- Tag device (add unique identifier), clearing existing one(s)
-- @param device (renoise.AudioDevice), leave out to simply clear

function RoamingDSP:tag_device(device)

  local display_name = self:get_unique_name()
  for _,track in ipairs(rns.tracks) do
    for k,d in ipairs(track.devices) do
      if (d.display_name==display_name) then
        d.display_name = d.name
      end
    end
  end

  if device then
    device.display_name = display_name
  end

end

--------------------------------------------------------------------------------
-- @see Duplex.Automateable.on_idle

function RoamingDSP:on_idle()

  if (not self.active) then 
    return 
  end

  -- set to the current device
  if self.current_device_requested then
    self.current_device_requested = false
    self:attach_to_selected_device()
    -- update prev/next
    local track_idx = rns.selected_track_index
    local device_idx = rns.selected_device_index
    self:update_prev_next(track_idx,device_idx)
    -- update lock button
    if self.target_device then
      self:update_lock_button()
    end

  end

  -- when device is unassignable, blink lock button
  if self._controls.lock_button and not self.target_device then
    local blink = (math.floor(os.clock()%2)==1)
    if blink~=self._blink then
      self._blink = blink
      if blink then
        self._controls.lock_button:set(self.palette.lock_on)
      else
        self._controls.lock_button:set(self.palette.lock_off)
      end
    end
  end

  Automateable.on_idle(self)


end

--------------------------------------------------------------------------------
-- Return the currently focused track->device in Renoise
-- @return Device

function RoamingDSP:get_selected_device()

  local track_idx = rns.selected_track_index
  local device_index = rns.selected_device_index
  return rns.tracks[track_idx].devices[device_index]   

end

--------------------------------------------------------------------------------
-- Attempt to select the current device 
-- failing to do so will clear the target device

function RoamingDSP:attach_to_selected_device()

  if (self.options.locked.value == RoamingDSP.LOCKED_DISABLED) then
    local device = self:get_selected_device()
    if self:device_is_valid(device) then
      local track_idx = rns.selected_track_index
      local device_idx = rns.selected_device_index
      self:attach_to_device(track_idx,device_idx,device)
    else
      self:clear_device()
    end
  end
end


--------------------------------------------------------------------------------
-- Attach notifier to the device 
-- called when we use previous/next device, set the initial device
-- or are freely roaming the tracks

function RoamingDSP:attach_to_device(track_idx,device_idx,device)

  -- clear the previous device references
  self:_remove_notifiers(self._parameter_observables)

  local track_changed = (self.track_index ~= track_idx)

  self.target_device = device
  self.track_index = track_idx
  self.device_index = device_idx

  -- new track? attach_to_track_devices
  if track_changed then
    local track = rns.tracks[track_idx]
    self:_attach_to_track_devices(track)
  end

  self:update_lock_button()

end


--------------------------------------------------------------------------------
-- Retrieve a parameter from the target device by name
-- @param param_name (string)
-- @return DeviceParameter or nil

function RoamingDSP:get_device_param(param_name)

  if (self.target_device) then
    for k,v in pairs(self.target_device.parameters) do
      if (v.name == param_name) then
        return v
      end
    end
  end

end

--------------------------------------------------------------------------------
-- Update automation 
-- @param track_idx, int
-- @param param, DeviceParameter
-- @param value, number
-- @param [playmode] renoise.PatternTrackAutomation.PLAYMODE_XX

function RoamingDSP:update_automation(track_idx,param,value,playmode)

  if self._record_mode then
    -- default to points mode
    if not playmode then
      playmode = renoise.PatternTrackAutomation.PLAYMODE_POINTS
    end
    self.automation.playmode = playmode
    self.automation:record(track_idx,param,value)
  end

end

--------------------------------------------------------------------------------
-- Keep track of devices (insert,remove,swap...)
-- invoked by `attach_to_device()`
-- @param track (renoise.Track)

function RoamingDSP:_attach_to_track_devices(track)
  TRACE("RoamingDSP:_attach_to_track_devices()",track)

  self:_remove_notifiers(self._device_observables)
  self._device_observables = table.create()

  self._device_observables:insert(track.devices_observable)
  track.devices_observable:add_notifier(
    function(notifier)
      --[[
      if (notifier.type == "insert") then
        -- TODO stop when index is equal to, or higher 
      end
      ]]
      if (notifier.type == "swap") and self.device_index then
        if (notifier.index1 == self.device_index) then
          self.device_index = notifier.index2
        elseif (notifier.index2 == self.device_index) then
          self.device_index = notifier.index1
        end
      end

      if (notifier.type == "remove") then

        local search = self:do_device_search()
        if not search then
          self:clear_device()
        else
          if (search.track_index ~= self.track_index) then
            self:clear_device()
            self:initial_select()
          end
        end
      end

    end
  )
end

--------------------------------------------------------------------------------
-- Select track + device, but only when follow_pos is enabled

function RoamingDSP:follow_device_pos()
  TRACE("RoamingDSP:follow_device_pos()")

  if (self.options.follow_pos.value == RoamingDSP.FOLLOW_POS_ENABLED) then
    if self.track_index then
      rns.selected_track_index = self.track_index
      rns.selected_device_index = self.device_index
    end
  end

end


--------------------------------------------------------------------------------
-- Update the state of the lock button

function RoamingDSP:update_lock_button()
  TRACE("RoamingDSP:update_lock_button()")

  if self._controls.lock_button then
    if (self.options.locked.value == RoamingDSP.LOCKED_ENABLED) then
      self._controls.lock_button:set(self.palette.lock_on)
    else
      self._controls.lock_button:set(self.palette.lock_off)
    end
  end

end


--------------------------------------------------------------------------------
-- @see Duplex.Application._build_app
-- @return bool

function RoamingDSP:_build_app()
  TRACE("RoamingDSP:_build_app()")

  local cm = self.display.device.control_map

  -- lock button
  local map = self.mappings.lock_button
  if map.group_name then
    local c = UIButton(self)
    c.group_name = map.group_name
    c.tooltip = map.description
    c:set_pos(map.index)
    c.on_press = function(obj)
      TRACE("RoamingDSP - lock_button.on_press()")
      local track_idx = rns.selected_track_index
      if (self.options.locked.value ~= RoamingDSP.LOCKED_ENABLED) then
        -- attempt to lock device
        if not self.target_device then
          return 
        end
        -- set preference and update device name 
        self:_set_option("locked",RoamingDSP.LOCKED_ENABLED,self._process)
        self:tag_device(self.target_device)
      else
        -- unlock only when locked
        if (self.options.locked.value == RoamingDSP.LOCKED_ENABLED) then
          -- set preference and update device name 
          self:_set_option("locked",RoamingDSP.LOCKED_DISABLED,self._process)
          self.current_device_requested = true
          self:tag_device(nil)
        end

      end
      self:update_lock_button()

    end
    self._controls.lock_button = c
  end

  -- previous device button
  local map = self.mappings.prev_device
  if map.group_name then
    local c = UIButton(self)
    c.group_name = map.group_name
    c.tooltip = map.description
    c:set_pos(map.index)
    c.on_press = function(obj)
      TRACE("RoamingDSP - prev_device.on_press()")
      self:goto_previous_device()
    end
    self._controls.prev_button = c
  end

  -- next device button
  local map = self.mappings.next_device
  if map.group_name then
    local c = UIButton(self)
    c.group_name = map.group_name
    c.tooltip = map.description
    c:set_pos(map.index)
    c.on_press = function(obj)
      TRACE("RoamingDSP - next_device.on_press()")
      self:goto_next_device()
    end
    self._controls.next_button = c
  end

  return true

end


--------------------------------------------------------------------------------
-- @see Duplex.Application.on_new_document

function RoamingDSP:on_new_document()

  rns = renoise.song()

  self:_attach_to_song()
  self:initial_select()

end

--------------------------------------------------------------------------------
-- @see Duplex.Application.on_release_document

function RoamingDSP:on_release_document()
  
  self:_remove_notifiers(self._device_observables)
  self.target_device = nil
  self.track_index = nil
  self.device_index = nil

end

--------------------------------------------------------------------------------
-- De-attach from the device

function RoamingDSP:clear_device()

  self:_remove_notifiers(self._parameter_observables)
  self.target_device = nil
  self.track_index = nil
  self.device_index = nil

end

--------------------------------------------------------------------------------
-- Attach notifiers to the song, handle changes
-- @see Duplex.Automateable._attach_to_song

function RoamingDSP:_attach_to_song()

  -- update when a device is selected
  rns.selected_device_observable:add_notifier(
    function()
      self.current_device_requested = true
    end
  )

  Automateable._attach_to_song(self)

end

--------------------------------------------------------------------------------

--- "brute force" removal of registered notifiers 
-- @param observables - list of observables

function RoamingDSP:_remove_notifiers(observables)

  for _,observable in pairs(observables) do
    -- temp security hack. can also happen when removing FX
    pcall(function() observable:remove_notifier(self) end)
  end
    
  observables:clear()

end

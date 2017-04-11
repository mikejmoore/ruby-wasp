class LoadTestSchedule
  attr_accessor :events
  
  def initialize
    @events = []
    @previous_action = nil
  end
  
  def add(time, action)
    if (action != @previous_action)
      remove_action_at_time(time)
      @events << {time: time, action: action}
    else
      warn "Attempt to add same action consecutively, ignoring the later one.  Time: #{time}  Action: #{action}"
    end
    @previous_action = action
  end
  
  def load_json(schedule_events)
    schedule_events.each do |event|
      time = event["time"].to_i
      action = event["action"].to_sym
      add(time, action)
    end
  end
  
  def remove_action_at_time(time)
    (0..@events.length - 1).each do |i|
      if (@events[i][:time] == time)
        @events.delete_at(i)
        return
      end
    end
  end
  
  
  def current_action(time)
    event = current_event(time)
    if (event == nil)
      return :pause
    else
      return event[:action]
    end
  end


  def next_action(time)
    event = next_event(time)
    if (event == nil)
      return nil
    else
      return event[:action]
    end
  end
  
  
  def current_event(time)
    current_event = nil
    @events.each do |event|
      if (event[:time] <= time.to_i)
        current_event = event
      end
    end
    return current_event
  end


  def next_event(time)
    current_event = nil
    @events.each do |event|
      if (event[:time] > time.to_i)
        return event
      end
    end
    return @events.last
  end
  
  
end
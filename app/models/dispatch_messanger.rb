class DispatchMessanger

  def initialize(responder)
    @responder = responder
    @dispatch  = responder.dispatches.latest
    @report    = @dispatch.report unless @dispatch.nil?
  end

  def respond(body)
    feedback = true
    if @responder.on_shift? && body[/break/i]
      @responder.shifts.end!('sms') && feedback = false if non_breaktime
      status = 'rejected' if @dispatch && @dispatch.pending?
    elsif !@responder.on_shift? && body[/on/i]
      @responder.shifts.start!('sms') && feedback = false
    elsif @dispatch.pending? && body[/no/i]
      status = 'rejected'
    elsif @dispatch.accepted? && body[/done/i]
      status = 'completed'
    elsif !@dispatch.accepted? && !@dispatch.completed?
      status = 'accepted'
    end
    @dispatch.update_attributes!(status: status)
    give_feedback(body) if feedback
  end

  def accept!
    @dispatch.update_attribute(:accepted_at, Time.now)
    @report.logs.create!(author: @responder, body: "*** Accepted the dispatch ***")
    acknowledge_acceptance
    notify_reporter
  end

  def complete!
    @report.complete!
    thank_responder
    thank_reporter
  end

  def pending!
    responder_synopses.each { |snippet| Telephony.send(snippet, @responder.phone) }
  end

  def reject!
    acknowledge_rejection
  end

private

  def acknowledge_acceptance
    Telephony.send("You have been assigned to an incident at #{@report.address}.", @responder.phone)
  end

  def acknowledge_rejection
    Telephony.send("You have been removed from this incident at #{@report.address}. You are now available to be dispatched.", @responder.phone)
  end

  def give_feedback(body)
    @report.logs.create!(author: @responder, body: body)
  end

  def non_breaktime
    @dispatch.nil? || @dispatch.completed? || @dispatch.pending?
  end

  def notify_reporter
    Telephony.send(reporter_synopsis, @report.phone)
  end

  def reporter_synopsis
    <<-SMS
    INCIDENT RESPONSE:
    #{@responder.name} is on the way.
    #{@responder.phone}
    SMS
  end

  def responder_synopses
    [
      @report.address,
      "Reporter: #{[@report.name, @report.phone].delete_blank * ', '}",
      "#{[@report.race, @report.gender, @report.age].delete_blank * '/'}",
      @report.setting,
      @report.nature
    ].delete_blank
  end

  def thank_responder
    Telephony.send("The report is now completed, thanks for your help! You are now available to be dispatched.", @responder.phone)
  end

  def thank_reporter
    Telephony.send("Report resolved, thanks for being concrned!", @report.phone)
  end
end

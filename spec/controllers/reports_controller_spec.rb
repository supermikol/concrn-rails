require "spec_helper"

describe ReportsController do
  # describe "POST /reports" do
  #   let(:report_data) { attributes_for(:report) }
  #   let(:user) { create(:responder, :jacob) }
  #
  #   describe "signed in" do
  #     before do
  #       sign_in user
  #     end
  #
  #     it "creates the report" do
  #       expect {
  #         post :create, :report => report_data
  #       }.to change(Report, :count).by(1)
  #     end
  #   end
  #
  #   describe "signed out" do
  #     it "creates the report" do
  #       expect {
  #         post :create, :report => report_data
  #       }.to change(Report, :count).by(1)
  #     end
  #   end
  # end

  context "when completing report" do
    let(:report) { create(:report, :accepted) }
    let(:additional_responder) { create(:user, :responder) }

    def complete_report(report_id)
      put :update, id: report_id, report: { status: :completed }
    end

    before do
      request.env['HTTP_REFERER'] = '/reports'
    end

    it "notifies dispatchers the report is complete" do
      report.dispatch(additional_responder.responder)

      report.dispatches.each do |dispatch|
        dispatch.update_attribute(:status, :accepted)
      end

      notified = []
      allow(Telephony).to receive(:send) do |body, to|
        next unless body =~ /The report is now completed/
        fail "#{to} has already been notified" if notified.include?(to)
        notified << to
      end

      complete_report(report.id)
      notified.should have(report.responders.count).items
    end

    it "notifies reporter once" do
      received = false
      allow(Telephony).to receive(:send) do |body, to|
        next unless body =~ /Report resolved, thanks for being concrned!/
        fail "#{to} has already been notified" if received
        received = true
      end

      complete_report(report.id)
      expect(received).to be
    end
  end
end

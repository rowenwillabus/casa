require "rails_helper"

RSpec.describe Volunteer, type: :model do
  describe "#activate" do
    let(:volunteer) { create(:volunteer, :inactive) }

    it "activates the volunteer" do
      volunteer.activate

      volunteer.reload
      expect(volunteer.active).to eq(true)
    end
  end

  describe "#deactivate" do
    let(:volunteer) { create(:volunteer) }

    it "deactivates the volunteer" do
      volunteer.deactivate

      volunteer.reload
      expect(volunteer.active).to eq(false)
    end

    it "sets all of a volunteer's case assignments to inactive" do
      case_contacts =
        3.times.map {
          create(:case_assignment, casa_case: create(:casa_case, casa_org: volunteer.casa_org), volunteer: volunteer)
        }

      volunteer.deactivate

      case_contacts.each { |c| c.reload }
      expect(case_contacts).to all(satisfy { |c| !c.is_active })
    end
  end

  describe "#display_name" do
    it "allows user to input dangerous values" do
      volunteer = create(:volunteer)
      UserInputHelpers::DANGEROUS_STRINGS.each do |dangerous_string|
        volunteer.update_attribute(:display_name, dangerous_string)
        volunteer.reload

        expect(volunteer.display_name).to eq dangerous_string
      end
    end
  end

  describe "#has_supervisor?" do
    context "when no supervisor_volunteer record" do
      let(:volunteer) { create(:volunteer) }

      it "returns false" do
        expect(volunteer.has_supervisor?).to be false
      end
    end

    context "when active supervisor_volunteer record" do
      let(:sv) { create(:supervisor_volunteer, is_active: true) }
      let(:volunteer) { sv.volunteer }

      it "returns true" do
        expect(volunteer.has_supervisor?).to be true
      end
    end

    context "when inactive supervisor_volunteer record" do
      let(:sv) { create(:supervisor_volunteer, is_active: false) }
      let(:volunteer) { sv.volunteer }

      it "returns false" do
        expect(volunteer.has_supervisor?).to be false
      end
    end
  end

  describe "#made_contact_with_all_cases_in_14_days?" do
    let(:volunteer) { create(:volunteer) }
    let(:casa_case) { create(:casa_case, casa_org: volunteer.casa_org) }
    let(:create_case_contact) do
      lambda { |occurred_at, contact_made|
        create(:case_contact, casa_case: casa_case, creator: volunteer, occurred_at: occurred_at, contact_made: contact_made)
      }
    end

    before do
      create(:case_assignment, casa_case: casa_case, volunteer: volunteer, is_active: true)
    end

    context "when volunteer has made recent contact" do
      it "returns true" do
        create_case_contact.call(Date.current, true)
        expect(volunteer.made_contact_with_all_cases_in_14_days?).to eq(true)
      end
    end

    context "when volunteer has made recent contact attempt but no contact made" do
      it "returns true" do
        create_case_contact.call(Date.current, false)
        expect(volunteer.made_contact_with_all_cases_in_14_days?).to eq(false)
      end
    end

    context "when volunteer has not made recent contact" do
      it "returns false" do
        create_case_contact.call(Date.current - 60.days, true)
        expect(volunteer.made_contact_with_all_cases_in_14_days?).to eq(false)
      end
    end

    context "when volunteer has not made recent contact in just one case" do
      it "returns false" do
        casa_case2 = create(:casa_case, casa_org: volunteer.casa_org)
        create(:case_assignment, casa_case: casa_case2, volunteer: volunteer, is_active: true)
        create(:case_contact, casa_case: casa_case2, creator: volunteer, occurred_at: Date.current - 60.days, contact_made: true)
        create_case_contact.call(Date.current, true)
        expect(volunteer.made_contact_with_all_cases_in_14_days?).to eq(false)
      end
    end

    context "when volunteer has no case assignments" do
      it "returns true" do
        volunteer2 = create(:volunteer)
        expect(volunteer2.made_contact_with_all_cases_in_14_days?).to eq(true)
      end
    end
  end

  describe "#supervised_by?" do
    it "is supervised by the currently active supervisor" do
      supervisor = create :supervisor
      volunteer = create :volunteer, supervisor: supervisor

      expect(volunteer).to be_supervised_by(supervisor)
    end

    it "is not supervised by supervisors that have never supervised the volunteer before" do
      supervisor = create :supervisor
      volunteer = create :volunteer

      expect(volunteer).to_not be_supervised_by(supervisor)
    end

    it "is not supervised by supervisor that had the volunteer unassinged" do
      old_supervisor = create :supervisor
      new_supervisor = create :supervisor
      volunteer = create :volunteer, supervisor: old_supervisor

      volunteer.update supervisor: new_supervisor

      expect(volunteer).to_not be_supervised_by(old_supervisor)
      expect(volunteer).to be_supervised_by(new_supervisor)
    end
  end

  describe "#role" do
    subject(:volunteer) { create :volunteer }

    it { expect(volunteer.role).to eq "Volunteer" }
  end

  describe "#with_no_supervisor" do
    subject { Volunteer.with_no_supervisor(casa_org) }

    let(:casa_org) { create(:casa_org) }

    context "no volunteers" do
      it "returns none" do
        expect(subject).to eq []
      end
    end

    context "volunteers" do
      let!(:unassigned1) { create(:volunteer, display_name: "aaa", casa_org: casa_org) }
      let!(:unassigned2) { create(:volunteer, display_name: "bbb", casa_org: casa_org) }
      let!(:unassigned2_different_org) { create(:volunteer, display_name: "ccc") }
      let!(:assigned1) { create(:volunteer, display_name: "ddd", casa_org: casa_org) }
      let!(:assignment1) { create(:supervisor_volunteer, volunteer: assigned1) }
      let!(:assigned2_different_org) { assignment1.volunteer }
      let!(:unassigned_inactive_volunteer) { create(:volunteer, display_name: "eee", casa_org: casa_org, active: false) }
      let!(:previously_assigned) { create(:volunteer, display_name: "fff", casa_org: casa_org) }
      let!(:inactive_assignment) { create(:supervisor_volunteer, volunteer: previously_assigned, is_active: false) }

      it "returns unassigned volunteers" do
        expect(subject.map(&:display_name).sort).to eq ["aaa", "bbb", "fff"]
      end
    end
  end
end

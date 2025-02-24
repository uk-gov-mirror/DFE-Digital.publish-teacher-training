require "rails_helper"

feature "View provider UCAS contact", type: :feature do
  let(:org_ucas_contacts_page) { PageObjects::Page::Organisations::UcasContacts.new }
  let(:provider) do
    build(
      :provider,
      provider_code: "A0",
      send_application_alerts: nil,
      contacts: contacts,
    )
  end

  let(:utt_contact) { build(:contact, :utt) }
  let(:web_link_contact) { build(:contact, :web_link) }
  let(:fraud_contact) { build(:contact, :fraud) }
  let(:finance_contact) { build(:contact, :finance) }
  let(:admin_contact) { build(:contact, :admin) }

  let(:contacts) do
    [
      utt_contact,
      web_link_contact,
      fraud_contact,
      finance_contact,
      admin_contact,
    ]
  end

  before do
    signed_in_user

    stub_api_v2_resource(provider, include: "contacts")
  end

  scenario "viewing organisation UCAS contacts page" do
    visit provider_ucas_contacts_path(provider.provider_code)

    expect(current_path).to eq provider_ucas_contacts_path(provider.provider_code)

    expect(org_ucas_contacts_page.title).to have_content("UCAS contacts")

    expect(org_ucas_contacts_page.utt_contact).to have_content(utt_contact.name)
    expect(org_ucas_contacts_page.web_link_contact).to have_content(web_link_contact.name)
    expect(org_ucas_contacts_page.finance_contact).to have_content(finance_contact.name)
    expect(org_ucas_contacts_page.fraud_contact).to have_content(fraud_contact.name)
    expect(org_ucas_contacts_page.admin_contact).to have_content(admin_contact.name)

    expect(org_ucas_contacts_page.gt12_contact).to have_content(provider.gt12_contact)
    expect(org_ucas_contacts_page.application_alert_contact).to have_content(provider.application_alert_contact)
    expect(org_ucas_contacts_page.send_application_alerts).to have_content("Don’t get an email")
  end

  context "email alerts: none" do
    let(:provider) { build(:provider, send_application_alerts: "none") }

    scenario "viewing organisation UCAS contacts page" do
      visit provider_ucas_contacts_path(provider.provider_code)
      expect(org_ucas_contacts_page.send_application_alerts).to have_content("Don’t get an email")
    end
  end

  context "email alerts: all" do
    let(:provider) { build(:provider, send_application_alerts: "all") }

    scenario "viewing organisation UCAS contacts page" do
      visit provider_ucas_contacts_path(provider.provider_code)
      expect(org_ucas_contacts_page.send_application_alerts).to have_content("Get an email for each application you receive")
    end
  end

  describe "can navigate to the edit alerts screen" do
    scenario "with the change alerts link" do
      visit provider_ucas_contacts_path(provider.provider_code)
      org_ucas_contacts_page.send_application_alerts_link.click
      expect(current_path).to eq alerts_provider_ucas_contacts_path(provider.provider_code)
    end

    scenario "with the change email link" do
      visit provider_ucas_contacts_path(provider.provider_code)
      org_ucas_contacts_page.application_alert_contact_link.click
      expect(current_path).to eq alerts_provider_ucas_contacts_path(provider.provider_code)
    end
  end
end

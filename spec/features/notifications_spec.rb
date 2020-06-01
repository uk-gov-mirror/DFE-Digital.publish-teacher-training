require "rails_helper"

feature "Notifications", type: :feature do
  let(:organisation_show_page) { PageObjects::Page::Organisations::OrganisationShow.new }
  let(:notifications_index_page) { PageObjects::Page::Notifications::IndexPage.new }

  let(:provider) { build :provider }
  let(:access_request) { build :access_request }
  let(:user) { build :user }

  before do
    stub_omniauth(user: user)
    stub_api_v2_resource(provider)
    stub_api_v2_resource(provider.recruitment_cycle)
    stub_api_v2_resource_collection([access_request])
  end

  context "When the provider is not an accredited body" do
    it "does not have the notifications link" do
      when_i_visit_providers_page
      then_i_should_not_see_notifications_link
    end
  end

  context "When the provider is an accredited body" do
    let(:provider) { build :provider, accredited_body?: true }

    it "organisation page does have the notifications link" do
      when_i_visit_accredited_body_page
      then_i_should_see_notifications_link
    end

    describe "User sets notification preferences for the first time" do
      it "should allow the user to opt into notifications" do
        given_a_user_has_never_set_their_preferences
        when_i_visit_accredited_body_page
        and_i_click_on_notifications_link
        then_the_notifications_page_is_displayed
        then_neither_radio_button_is_selected
        and_i_select_yes
        and_save_my_choice
        then_i_should_see_my_preferences_have_been_saved
      end
    end

    describe "User updates notification preferences" do
      it "should allow the user to opt into notifications" do
        given_a_user_has_previously_set_their_preferences
        when_i_visit_accredited_body_page
        and_i_click_on_notifications_link
        then_the_notifications_page_is_displayed
        then_yes_radio_button_is_preselected
        and_i_select_no
        and_save_my_choice
        then_i_should_see_my_preferences_have_been_saved
      end
    end
  end

private

  def given_a_user_has_never_set_their_preferences
    notification = build(
      :user_notification_preferences,
      id: user.id,
      updated_at: nil,
      enabled: false,
    )

    stub_api_v2_request(
      "/user_notification_preferences/#{user.id}",
      resource_list_to_jsonapi([notification]),
    )
  end

  def given_a_user_has_previously_set_their_preferences
    notification = build(
      :user_notification_preferences,
      id: user.id,
      updated_at: Time.zone.now,
      enabled: true,
    )

    stub_api_v2_request(
      "/user_notification_preferences/#{user.id}",
      resource_list_to_jsonapi([notification]),
    )
  end

  def when_i_visit_providers_page
    visit provider_path(provider.provider_code)
  end

  def when_i_visit_accredited_body_page
    when_i_visit_providers_page
  end

  def then_i_should_see_notifications_link
    expect(organisation_show_page).to have_notifications_preference_link
  end

  def then_i_should_not_see_notifications_link
    expect(organisation_show_page).not_to have_notifications_preference_link
  end

  def and_i_click_on_notifications_link
    organisation_show_page.notifications_preference_link.click
  end

  def then_the_notifications_page_is_displayed
    expect(notifications_index_page).to be_displayed
  end

  def and_i_select_yes
    params = { "data" =>
      { "id" => user.id.to_s,
        "type" => "user_notification_preferences",
        "attributes" => { "enabled" => "true" } } }.to_json

    response_body =
      { "_jsonapi" =>
        { "data" =>
          { "type" => "user_notification_preferences",
            "id" => user.id.to_s,
            "attributes" =>
            { "enabled" => "true",
              "updated_at" => "2020-05-20T10:00:00+01:00"  }  }  }  }

    @put_request = stub_api_v2_request(
      "/user_notification_preferences/#{user.id}",
      response_body,
      :patch,
      200,
      body: params,
    )
    notifications_index_page.opt_in_radio.click
  end

  def and_i_select_no
    params = { "data" =>
      { "id" => user.id.to_s,
        "type" => "user_notification_preferences",
        "attributes" => { "enabled" => "false" } } }.to_json

    response_body =
      { "_jsonapi" =>
        { "data" =>
          { "type" => "user_notification_preferences",
            "id" => user.id.to_s,
            "attributes" =>
            { "enabled" => "false",
              "updated_at" => "2020-05-20T10:00:00+01:00"  }  }  }  }

    @put_request = stub_api_v2_request(
      "/user_notification_preferences/#{user.id}",
      response_body,
      :patch,
      200,
      body: params,
    )
    notifications_index_page.opt_out_radio.click
  end

  def and_save_my_choice
    notifications_index_page.save_button.click
  end

  def then_i_should_see_my_preferences_have_been_saved
    expect(@put_request).to have_been_made
    expect(organisation_show_page)
      .to have_content("Your notification preferences have been saved")
  end

  def then_yes_radio_button_is_preselected
    expect(notifications_index_page.opt_in_radio).to be_checked
  end

  def then_neither_radio_button_is_selected
    expect(notifications_index_page.opt_in_radio).not_to be_checked
    expect(notifications_index_page.opt_out_radio).not_to be_checked
  end
end

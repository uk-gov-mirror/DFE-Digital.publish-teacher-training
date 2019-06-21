require 'rails_helper'

feature 'Edit course vacancies', type: :feature do
  let(:course_vacancies_page) { PageObjects::Page::Organisations::CourseVacancies.new }
  let(:courses_page) { PageObjects::Page::Organisations::Courses.new }
  let(:course_code) { 'X104' }

  let!(:sync_courses_request_stub) do
    stub_request(
      :post,
      "http://localhost:3001/api/v2/providers/AO/courses/" \
        "#{course_code}/sync_with_search_and_compare"
    ).to_return(status: 201, body: "")
  end

  before do
    stub_omniauth
    stub_api_v2_request("/providers/AO?include=courses.accrediting_provider", jsonapi(:provider).render)
    stub_request(:patch, %r{\Ahttp://localhost:3001/api/v2/site_statuses/\d+})
    stub_course_request(course)
    course_vacancies_page.load_with_course(course)
  end

  context 'A full time course with multiple running sites' do
    let(:course) do
      jsonapi(
        :course,
        :with_full_time_vacancy,
        course_code: course_code,
        site_statuses: [
          jsonapi_site_status('Running Uni 1', :full_time, 'running'),
          jsonapi_site_status('Running Uni 2', :full_time, 'running'),
          jsonapi_site_status('Not running Uni', :full_time, 'suspended')
        ]
      )
    end

    scenario 'shows the edit vacancies page' do
      expect(course_vacancies_page).to have_link('Back', href: provider_courses_path('AO'))
      expect(course_vacancies_page).to have_link('Cancel changes', href: provider_courses_path('AO'))
      expect(course_vacancies_page.title).to have_content('Edit vacancies')
      expect(course_vacancies_page.caption).to have_content(
        "#{course.name} (#{course.course_code})"
      )
    end

    scenario 'only render site statuses that are running' do
      expect(course_vacancies_page).to have_vacancies_radio_choice
      expect(course_vacancies_page.vacancies_radio_has_some_vacancies).to be_checked

      [
        ["Running Uni 1", true],
        ["Running Uni 2", true]
      ].each do |name, checked|
        expect(course_vacancies_page.vacancies_running_sites_checkboxes).to have_field(name, checked: checked)
      end

      expect(course_vacancies_page.vacancies_running_sites_checkboxes).not_to have_field("Not running Uni")
    end
  end

  context 'A full time course with multiple running sites but no vacancies' do
    let(:course) do
      jsonapi(
        :course,
        :full_time,
        course_code: course_code,
        site_statuses: [
          jsonapi_site_status('Running Uni 1', :no_vacancies, 'running'),
          jsonapi_site_status('Running Uni 2', :no_vacancies, 'running')
        ]
      )
    end

    scenario 'shows course as having no vacancies' do
      expect(course_vacancies_page).to have_vacancies_radio_choice
      expect(course_vacancies_page.vacancies_radio_no_vacancies).to be_checked
      expect(course_vacancies_page.vacancies_radio_has_some_vacancies).not_to be_checked

      [
        ["Running Uni 1", false],
        ["Running Uni 2", false]
      ].each do |name, checked|
        expect(course_vacancies_page.vacancies_running_sites_checkboxes).to have_field(name, checked: checked)
      end
    end
  end

  context 'A full time or part time course with multiple running sites' do
    let(:course) do
      jsonapi(
        :course,
        :with_full_time_or_part_time_vacancy,
        course_code: course_code,
        site_statuses: [
          jsonapi_site_status('Uni 1', :full_time, 'running'),
          jsonapi_site_status('Uni 2', :part_time, 'running'),
          jsonapi_site_status('Uni 3', :full_time_and_part_time, 'running'),
          jsonapi_site_status('Not running Uni', :full_time, 'suspended')
        ]
      )
    end

    scenario 'shows both study modes for each site' do
      expect(course_vacancies_page).to have_vacancies_radio_choice
      expect(course_vacancies_page.vacancies_radio_has_some_vacancies).to be_checked

      [
        ["Uni 1 (Full time)", true],
        ["Uni 1 (Part time)", false],
        ["Uni 2 (Full time)", false],
        ["Uni 2 (Part time)", true],
        ["Uni 3 (Full time)", true],
        ["Uni 3 (Part time)", true]
      ].each do |name, checked|
        expect(course_vacancies_page.vacancies_running_sites_checkboxes).to have_field(name, checked: checked)
      end
    end
  end

  context 'Removing vacancies for a course' do
    let(:course) do
      jsonapi(
        :course,
        :with_full_time_or_part_time_vacancy,
        course_code: course_code,
        site_statuses: [
          jsonapi_site_status('Uni 1', :full_time, 'running')
        ]
      )
    end

    scenario 'removing a full time vacancy' do
      expect(course_vacancies_page.vacancies_radio_has_some_vacancies).to be_checked
      uncheck("Uni 1 (Full time)")
      publish_changes
    end

    scenario 'removing all vacancies' do
      expect(course_vacancies_page.vacancies_radio_has_some_vacancies).to be_checked

      choose 'There are no vacancies'
      expect(course_vacancies_page.vacancies_radio_no_vacancies).to be_checked

      publish_changes
    end
  end

  context 'Adding vacancies for a course' do
    let(:course) do
      jsonapi(
        :course,
        :with_full_time_or_part_time_vacancy,
        course_code: course_code,
        site_statuses: [
          jsonapi_site_status('Uni 1', :full_time, 'running')
        ]
      )
    end

    scenario 'adding a part time vacancy' do
      check("Uni 1 (Part time)")
      publish_changes
    end
  end

  def publish_changes
    click_on 'Publish changes'
    expect(courses_page).to be_displayed
    expect(courses_page.flash).to have_content('Course vacancies published')
    expect(sync_courses_request_stub).to have_been_requested
  end

  def jsonapi_site_status(name, study_mode, status)
    jsonapi(:site_status, study_mode, site: jsonapi(:site, location_name: name), status: status)
  end

  def stub_course_request(course)
    stub_api_v2_request(
      "/providers/AO/courses/#{course.course_code}?include=site_statuses.site",
      course.render
    )
  end
end

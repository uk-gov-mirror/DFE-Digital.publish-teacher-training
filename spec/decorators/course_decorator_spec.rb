require "rails_helper"

describe CourseDecorator do
  let(:current_recruitment_cycle) { build :recruitment_cycle }
  let(:next_recruitment_cycle) { build :recruitment_cycle, :next_cycle }
  let(:provider) { build(:provider, accredited_body?: false) }
  let(:english) { build(:subject, :english) }
  let(:biology) { build(:subject, :biology) }
  let(:mathematics) { build(:subject, :mathematics) }
  let(:subjects) { [english, mathematics] }

  let(:course) do
    build(
      :course,
      course_code: "A1",
      name: "Mathematics",
      qualification: "pgce_with_qts",
      study_mode: "full_time",
      start_date: start_date,
      site_statuses: [site_status],
      provider: provider,
      accrediting_provider: provider,
      course_length: "OneYear",
      subjects: subjects,
      open_for_applications?: true,
      last_published_at: "2019-03-05T14:42:34Z",
      recruitment_cycle: current_recruitment_cycle,
    )
  end
  let(:start_date) { Time.zone.local(2019) }
  let(:site) { build(:site) }
  let(:site_status) do
    build(:site_status, :full_time_and_part_time, site: site)
  end

  let(:course_response) do
    course.to_jsonapi(
      include: %i[sites provider accrediting_provider recruitment_cycle subjects],
    )
  end

  let(:decorated_course) { course.decorate }

  it "returns the course name and code in brackets" do
    expect(decorated_course.name_and_code).to eq("Mathematics (A1)")
  end

  it "returns a list of subjects in alphabetical order" do
    expect(decorated_course.sorted_subjects).to eq("English<br>Mathematics")
  end

  it "returns if applications are open or closed" do
    expect(decorated_course.open_or_closed_for_applications).to eq("Open")
  end

  it "returns if course is an apprenticeship" do
    expect(decorated_course.apprenticeship?).to eq("No")
  end

  it "returns if course is SEND?" do
    expect(decorated_course.is_send?).to eq("No")
  end

  it "returns the Find URL" do
    expect(decorated_course.find_url).to eq("#{Settings.search_ui.base_url}/course/#{provider.provider_code}/#{course.course_code}")
  end

  it "returns course length" do
    expect(decorated_course.length).to eq("1 year")
  end

  context "recruitment cycles" do
    before do
      allow(Settings).to receive(:current_cycle).and_return(2019)
    end

    context "for a course in the current cycle" do
      let(:course) do
        build(:course, recruitment_cycle: current_recruitment_cycle)
      end

      it "knows which cycle it’s in" do
        expect(decorated_course.next_cycle?).to eq(false)
        expect(decorated_course.current_cycle?).to eq(true)
      end
    end

    context "for a course in the next cycle" do
      let(:course) do
        build(:course, recruitment_cycle: next_recruitment_cycle)
      end

      it "knows which cycle it’s in" do
        expect(decorated_course.next_cycle?).to eq(true)
        expect(decorated_course.current_cycle?).to eq(false)
      end
    end
  end

  context "status tag" do
    let(:status_tag) { course.decorate.status_tag }

    context "A non running course" do
      let(:course) { build(:course, ucas_status: "not_running") }

      it "Returns phase tag withdrawn" do
        expect(status_tag).to include("phase-tag--withdrawn")
      end

      it "Returns text withdrawn" do
        expect(status_tag).to include("Withdrawn")
      end
    end

    context "An empty course" do
      let(:course) { build(:course, content_status: "empty") }

      it "Returns phase tag published" do
        expect(status_tag).to include("phase-tag--no-content")
      end

      it "Returns text empty" do
        expect(status_tag).to include("Empty")
      end
    end

    context "A draft course" do
      let(:course) { build(:course, content_status: "draft") }

      it "Returns phase tag published" do
        expect(status_tag).to include("phase-tag--draft")
      end

      it "Returns text draft" do
        expect(status_tag).to include("Draft")
      end
    end

    context "A published with unpublished changes course" do
      let(:course) { build(:course, content_status: "published_with_unpublished_changes") }

      it "Returns phase tag published" do
        expect(status_tag).to include("phase-tag--published")
      end

      it "Returns text published*" do
        expect(status_tag).to include("Published&nbsp;*")
      end

      it "Returns unpublished status hint" do
        expect(status_tag).to include("*&nbsp;Unpublished&nbsp;changes")
      end
    end

    context "A rolled over course" do
      let(:course) { build(:course, content_status: "rolled_over") }

      it "Returns phase tag no content" do
        expect(status_tag).to include("phase-tag--no-content")
      end

      it "Returns text rolled over" do
        expect(status_tag).to include("Rolled over")
      end
    end

    context "A withdrawn course" do
      let(:course) { build(:course, content_status: "withdrawn") }

      it "Returns phase tag withdrawn" do
        expect(status_tag).to include("phase-tag--withdrawn")
      end

      it "Returns text withdrawn" do
        expect(status_tag).to include("Withdrawn")
      end
    end
  end

  describe "#selectable_subjects" do
    let(:course) do
      build(
        :course,
        edit_options: {
          subjects: subjects.map do |subject|
            subject.to_jsonapi[:data]
          end,
        },
      )
    end

    it "gets the name and id" do
      expect(decorated_course.selectable_subjects).to eq([
        [english.subject_name, english.id],
        [mathematics.subject_name, mathematics.id],
      ])
    end
  end

  describe "#selected_subject_ids" do
    let(:selectable_subjects) { [english, mathematics] }
    let(:subjects) { [biology, mathematics] }

    let(:course) do
      build(
        :course,
        subjects: subjects,
        edit_options: {
          subjects: subjects.map do |subject|
            subject.to_jsonapi[:data]
          end,
        },
      )
    end

    it "returns ids for only subjects that are selectable" do
      expect(decorated_course.selected_subject_ids).to match_array([biology.id, mathematics.id])
    end
  end

  describe "#subject_present?" do
    it "returns true when the subject id exists" do
      expect(decorated_course.subject_present?(english)).to eq(true)
    end

    it "returns true when the subject id does not exists" do
      expect(decorated_course.subject_present?(biology)).to eq(false)
    end
  end

  context "financial incentives" do
    describe "#salaried?" do
      let(:subject) { decorated_course }

      context "course is salaried" do
        let(:course) { build :course, funding_type: "salary" }

        it { is_expected.to be_salaried }
      end

      context "course is an apprenticeship with salary" do
        let(:course) { build :course, funding_type: "apprenticeship" }

        it { is_expected.to be_salaried }
      end

      context "course is not salaried" do
        let(:course) { build :course, :with_fees }

        it { is_expected.to_not be_salaried }
      end
    end

    describe "#funding_option" do
      let(:subject) { decorated_course.funding_option }

      context "Salary" do
        let(:course) { build :course, funding_type: "salary" }

        it { is_expected.to eq("Salary") }
      end

      context "Apprenticeship" do
        let(:course) { build :course, funding_type: "apprenticeship" }

        it { is_expected.to eq("Salary") }
      end

      context "Bursary and Scholarship" do
        let(:mathematics) { build(:subject, :mathematics, scholarship: "2000", bursary_amount: "3000") }
        let(:course) { build :course, subjects: [mathematics] }

        it { is_expected.to eq("Scholarships or bursaries, as well as student finance, are available if you’re eligible") }
      end

      context "Bursary" do
        let(:mathematics) { build(:subject, :mathematics, bursary_amount: "3000") }
        let(:course) { build :course, subjects: [mathematics] }

        it { is_expected.to eq("Bursaries and student finance are available if you’re eligible") }
      end

      context "Student finance" do
        let(:course) { build :course }

        it { is_expected.to eq("Student finance if you’re eligible") }
      end

      context "Courses excluded from bursaries" do
        let(:pe) { build(:subject) }
        let(:english) { build(:subject, :english, bursary_amount: "3000") }

        let(:course) { build :course, name: "Drama with English", subjects: [pe, english] }

        it { is_expected.to eq("Student finance if you’re eligible") }
      end
    end

    describe "#subject_name" do
      context "course has more than one subject" do
        it "returns the course name" do
          expect(decorated_course.subject_name).to eq("Mathematics")
        end
      end

      context "course has one subject" do
        let(:subject) { build :subject, subject_name: "Computer Science" }
        let(:course) { build :course, subjects: [subject] }

        it "return the subject name" do
          expect(decorated_course.subject_name).to eq("Computer Science")
        end
      end
    end

    describe "#bursary_requirements" do
      let(:subject) { decorated_course.bursary_requirements }

      context "Course with mathematics as a subject" do
        let(:mathematics) { build :subject, :mathematics, subject_name: "Primary with Mathematics" }
        let(:english) { build :subject, :english }
        let(:subjects) { [mathematics, english] }

        expected_requirements = [
          "a degree of 2:2 or above in any subject",
          "at least grade B in maths A-level (or an equivalent)",
        ]

        it { is_expected.to eq(expected_requirements) }
      end

      context "Course without mathematics as a subject" do
        let(:english) { build :subject, :english }
        let(:subjects) { [biology, english] }

        expected_requirements = [
          "a degree of 2:2 or above in any subject",
        ]

        it { is_expected.to eq(expected_requirements) }
      end
    end

    describe "#bursary_first_line_ending" do
      let(:subject) { decorated_course.bursary_first_line_ending }

      context "More than one requirement" do
        let(:mathematics) { build :subject, :mathematics, subject_name: "Primary with Mathematics" }
        let(:english) { build :subject, :english }
        let(:subjects) { [mathematics, english] }

        expected_line_ending = ":"

        it { is_expected.to eq(expected_line_ending) }
      end

      context "Course without mathematics as a subject" do
        let(:english) { build :subject, :english }
        let(:subjects) { [biology, english] }

        expected_line_ending = "a degree of 2:2 or above in any subject."

        it { is_expected.to eq(expected_line_ending) }
      end
    end

    describe "#bursary_only" do
      let(:subject) { decorated_course }

      context "course only has bursary financial incentives" do
        let(:mathematics) { build :subject, bursary_amount: "2000" }
        let(:english) { build :subject, bursary_amount: "4000" }
        let(:subjects) { [mathematics, english] }

        it { is_expected.to be_bursary_only }
      end

      context "course has other financial incentives apart from bursaries" do
        let(:mathematics) { build :subject, bursary_amount: "2000" }
        let(:english) { build :subject, scholarship: "4000" }
        let(:subjects) { [mathematics, english] }

        it { is_expected.to_not be_bursary_only }
      end
    end

    describe "#has_bursary" do
      context "course has no bursary" do
        it "returns false" do
          expect(decorated_course.has_bursary?).to eq(false)
        end
      end

      context "course has bursary" do
        let(:mathematics) { build :subject, bursary_amount: "2000" }
        let(:english) { build :subject, bursary_amount: "4000" }
        let(:subjects) { [biology, mathematics, english] }

        it "returns true" do
          expect(decorated_course.has_bursary?).to eq(true)
        end
      end
    end

    describe "#bursary_amount" do
      context "course has bursary" do
        let(:mathematics) { build :subject, bursary_amount: "2000" }
        let(:english) { build :subject, bursary_amount: "4000" }
        let(:subjects) { [biology, mathematics, english] }

        it "returns the maximum bursary amount" do
          expect(decorated_course.bursary_amount).to eq("4000")
        end
      end
    end

    describe "#excluded_from_bursary?" do
      let(:subject) { decorated_course }

      context "course name does not qualify for exclusion" do
        let(:course) { build(:course, name: "Mathematics") }

        it { is_expected.to_not be_excluded_from_bursary }
      end

      context "course name contains 'with'" do
        context "Drama" do
          let(:english) { build :subject, bursary_amount: "30000" }
          let(:drama) { build :subject, subject_name: "Drama" }
          let(:subjects) { [english, drama] }

          context "Drama with English" do
            let(:course) { build(:course, name: "Drama with English", subjects: subjects) }

            it { is_expected.to be_excluded_from_bursary }
          end

          context "English with Drama" do
            let(:course) { build(:course, name: "English with Drama", subjects: subjects) }

            it { is_expected.to_not be_excluded_from_bursary }
          end
        end

        context "PE" do
          let(:english) { build :subject, bursary_amount: "30000" }
          let(:pe) { build :subject, subject_name: "PE" }
          let(:subjects) { [english, pe] }

          context "PE with English" do
            let(:course) { build(:course, name: "PE with English", subjects: subjects) }

            it { is_expected.to be_excluded_from_bursary }
          end

          context "English with PE" do
            let(:course) { build(:course, name: "English with PE", subjects: subjects) }

            it { is_expected.to_not be_excluded_from_bursary }
          end
        end

        context "Physical Education" do
          let(:english) { build :subject, bursary_amount: "30000" }
          let(:physical_education) { build :subject, subject_name: "Physical Education" }
          let(:subjects) { [english, physical_education] }

          context "Physical Education with English" do
            let(:course) { build(:course, name: "Physical Education with English", subjects: subjects) }

            it { is_expected.to be_excluded_from_bursary }
          end

          context "English with Physical Education" do
            let(:course) { build(:course, name: "English with Physical Education", subjects: subjects) }

            it { is_expected.to_not be_excluded_from_bursary }
          end
        end

        context "Media Studies" do
          let(:english) { build :subject, bursary_amount: "30000" }
          let(:media_studies) { build :subject, subject_name: "Media Studies" }
          let(:subjects) { [english, media_studies] }

          context "Media Studies with English" do
            let(:course) { build(:course, name: "Media Studies with English", subjects: subjects) }

            it { is_expected.to be_excluded_from_bursary }
          end

          context "English with Media Studies" do
            let(:course) { build(:course, name: "English with Media Studies", subjects: subjects) }

            it { is_expected.to_not be_excluded_from_bursary }
          end
        end
      end

      context "course name contains 'and'" do
        let(:english) { build :subject, bursary_amount: "30000" }
        let(:drama) { build :subject, subject_name: "Drama" }
        let(:subjects) { [english, drama] }

        context "Drama and English" do
          let(:course) { build(:course, name: "Drama and English", subjects: subjects) }

          it { is_expected.to_not be_excluded_from_bursary }
        end

        context "English and Drama" do
          let(:course) { build(:course, name: "English and Drama", subjects: subjects) }

          it { is_expected.to_not be_excluded_from_bursary }
        end
      end
    end

    describe "#scholarship_amount" do
      context "course has scholarship" do
        let(:mathematics) { build :subject, scholarship: "2000" }
        let(:english) { build :subject, scholarship: "4000" }
        let(:subjects) { [biology, mathematics, english] }

        it "returns the maximum scholarship amount" do
          expect(decorated_course.scholarship_amount).to eq("4000")
        end
      end
    end

    context "#has_scholarship?" do
      context "course has no scholarship" do
        it "returns false" do
          expect(decorated_course.has_scholarship?).to eq(false)
        end
      end

      context "course has scholarship" do
        let(:mathematics) { build :subject, scholarship: "6000" }
        let(:english) { build :subject, scholarship: "8000" }
        let(:subjects) { [biology, mathematics, english] }

        it "returns true" do
          expect(decorated_course.has_scholarship?).to eq(true)
        end
      end
    end

    context "early careers payment option" do
      context "course has no early career payment option" do
        it "returns false" do
          expect(decorated_course.has_early_career_payments?).to eq(false)
        end
      end

      context "course has early career payment option" do
        let(:english) { build :subject, early_career_payments: "2000" }
        let(:subjects) { [biology, mathematics, english] }

        it "returns true" do
          expect(decorated_course.has_early_career_payments?).to eq(true)
        end
      end
    end
  end

  describe "return_start_date" do
    context "when the course has a start date" do
      it "should return the course's start date" do
        expect(decorated_course.return_start_date).to eq(course.start_date)
      end
    end

    context "when the course has no start date" do
      let(:start_date) { nil }

      it "should return the September of the current cycle" do
        expect(decorated_course.return_start_date).to eq("September #{Settings.current_cycle}")
      end
    end

    context "during rollover" do
      let(:start_date) { nil }

      before { allow(Settings.features.rollover).to receive(:can_edit_current_and_next_cycles).and_return(true) }

      it "should return the September of the next cycle" do
        expect(decorated_course.return_start_date).to eq("September #{Settings.current_cycle + 1}")
      end
    end
  end

  describe "#other_course_length?" do
    context "when course_length is a pre-defined value" do
      let(:course) { build(:course, course_length: "OneYear") }

      it "returns false" do
        expect(decorated_course.other_course_length?).to be_falsey
      end
    end

    context "when course_length is nil" do
      let(:course) { build(:course, course_length: nil) }

      it "returns false so there is no default value" do
        expect(decorated_course.other_course_length?).to be_falsey
      end
    end

    context "when course_length is user set" do
      let(:course) { build(:course, course_length: "3 months") }

      it "returns true" do
        expect(decorated_course.other_course_length?).to be_truthy
      end
    end
  end

  describe "#placements_heading" do
    context "when the subject is not further education" do
      let(:course) { build(:course) }

      it "returns school placements" do
        expect(decorated_course.placements_heading).to eq("How school placements work")
      end
    end

    context "when the subject is further education" do
      let(:course) { build(:course, level: "further_education") }

      it "returns teaching placements" do
        expect(decorated_course.placements_heading).to eq("How teaching placements work")
      end
    end
  end

  describe "#subject_page_title" do
    let(:subject_page_title) { course.decorate.subject_page_title }

    context "a primary course" do
      let(:course) { build :course, level: "primary" }

      it "returns the correct page title" do
        expect(subject_page_title).to eq("Pick a primary subject")
      end
    end

    context "a secondary course" do
      let(:course) { build :course, level: "secondary" }

      it "returns the correct page title" do
        expect(subject_page_title).to eq("Pick a secondary subject")
      end
    end

    context "a further education course" do
      let(:course) { build :course, level: "further_education" }

      it "returns the correct page title" do
        expect(subject_page_title).to eq("Pick a subject")
      end
    end
  end

  describe "#changing_basic_details" do
    context "basic details when course is further education" do
      let(:course) { build :course, level: "further_education" }

      it "returns the correct details under 'changing your basic details'" do
        expect(decorated_course.listing_basic_details).to eq(["outcome",
                                                              "full time or part time",
                                                              "fee or salary",
                                                              "application open date",
                                                              "course start date"])
      end
    end

    context "basic details when course is primary or secondary" do
      let(:course) { build :course }

      it "returns the correct details under 'changing your basic details'" do
        expect(decorated_course.listing_basic_details).to eq(["age range",
                                                              "outcome",
                                                              "full time or part time",
                                                              "application open date",
                                                              "course start date",
                                                              "GCSE requirements"])
      end
    end
  end

  describe "#subject_input_label" do
    let(:subject_input_label) { course.decorate.subject_input_label }

    context "a primary course" do
      let(:course) { build :course, level: "primary" }

      it "returns the correct input label" do
        expect(subject_input_label).to eq("Primary subject")
      end
    end

    context "a secondary course" do
      let(:course) { build :course, level: "secondary" }

      it "returns the correct input label" do
        expect(subject_input_label).to eq("Secondary subject")
      end
    end

    context "a further education course" do
      let(:course) { build :course, level: "further_education" }

      it "returns the correct input label" do
        expect(subject_input_label).to eq("Pick a subject")
      end
    end
  end

  describe "#cycle_range" do
    let(:expected_cycle_range) do
      "#{current_recruitment_cycle.year} to #{(current_recruitment_cycle.year.to_i + 1)}"
    end

    subject { course.decorate.cycle_range }

    it "should state the correct cycle range" do
      expect(subject).to eq(expected_cycle_range)
    end
  end

  describe "#use_financial_support_placeholder?" do
    before do
      allow(Settings).to receive(:financial_support_placeholder_cycle)
        .and_return(financial_support_placeholder_cycle)
    end

    subject { course.decorate.use_financial_support_placeholder? }
    context "financial_support_placeholder_cycle is nil" do
      let(:financial_support_placeholder_cycle) { nil }

      it "should be false" do
        expect(subject).to be_falsey
      end
    end
    context "financial_support_placeholder_cycle not the same as course recruitment_cycle_year" do
      let(:financial_support_placeholder_cycle) do
        course.recruitment_cycle_year.to_i + 1
      end
      it "should be false" do
        expect(subject).to be_falsey
      end
    end

    context "financial_support_placeholder_cycle same as course recruitment_cycle_year" do
      let(:financial_support_placeholder_cycle) do
        course.recruitment_cycle_year.to_i
      end
      it "should be true" do
        expect(subject).to be_truthy
      end
    end
  end
end

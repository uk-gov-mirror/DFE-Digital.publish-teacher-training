# frozen_string_literal: true

module Find
  class CycleTimetable
    CYCLE_DATES = {
      2021 => {
        find_opens: Time.zone.local(2020, 10, 6, 9),
        apply_opens: Time.zone.local(2020, 10, 13, 9),
        first_deadline_banner: Time.zone.local(2021, 7, 12, 9),
        apply_1_deadline: Time.zone.local(2021, 9, 7, 18),
        apply_deadline: Time.zone.local(2021, 9, 21, 18),
        find_closes: Time.zone.local(2021, 10, 4).end_of_day,
      },
      2022 => {
        find_opens: Time.zone.local(2021, 10, 5, 9),
        apply_opens: Time.zone.local(2021, 10, 12, 9),
        first_deadline_banner: Time.zone.local(2022, 8, 2, 9),
        apply_1_deadline: Time.zone.local(2022, 9, 6, 18),
        apply_deadline: Time.zone.local(2022, 9, 20, 18),
        find_closes: Time.zone.local(2022, 10, 3).end_of_day,
      },
      2023 => {
        find_opens: Time.zone.local(2022, 10, 4, 9),
        apply_opens: Time.zone.local(2022, 10, 11, 9),
        first_deadline_banner: Time.zone.local(2023, 8, 1, 9),
        apply_1_deadline: Time.zone.local(2023, 9, 5, 18),
        apply_deadline: Time.zone.local(2023, 9, 19, 18),
        find_closes: Time.zone.local(2023, 10, 2).end_of_day,
      },
      2024 => {
        find_opens: Time.zone.local(2023, 10, 3, 9),
        apply_opens: Time.zone.local(2023, 10, 10, 9),
        first_deadline_banner: Time.zone.local(2024, 7, 30, 9),
        apply_deadline: Time.zone.local(2024, 9, 17, 18),
        find_closes: Time.zone.local(2024, 9, 30).end_of_day,
      },
      2025 => {
        find_opens: Time.zone.local(2024, 10, 1, 9),
        apply_opens: Time.zone.local(2024, 10, 8, 9),
        first_deadline_banner: Time.zone.local(2025, 7, 12, 9),
        apply_deadline: Time.zone.local(2025, 9, 16, 18),
        find_closes: Time.zone.local(2025, 9, 29).end_of_day,
      },
      2026 => {
        find_opens: Time.zone.local(2025, 9, 30, 9),
        apply_opens: Time.zone.local(2025, 10, 7, 9),
        first_deadline_banner: Time.zone.local(2026, 7, 12, 9),
        apply_deadline: Time.zone.local(2026, 9, 15, 18),
        find_closes: Time.zone.local(2026, 9, 28).end_of_day,
      },
      2027 => {
        find_opens: Time.zone.local(2026, 9, 29, 9),
        apply_opens: Time.zone.local(2026, 10, 6, 9),
        first_deadline_banner: Time.zone.local(2027, 7, 12, 9),
        apply_deadline: Time.zone.local(2027, 9, 21, 18),
        find_closes: Time.zone.local(2027, 10, 4).end_of_day,
      },
      2028 => {
        find_opens: Time.zone.local(2027, 10, 5, 9),
        apply_opens: Time.zone.local(2027, 10, 12, 9),
        first_deadline_banner: Time.zone.local(2028, 7, 12, 9),
        apply_deadline: Time.zone.local(2028, 9, 19, 18),
        find_closes: Time.zone.local(2028, 10, 2).end_of_day,
      },
      2029 => {
        find_opens: Time.zone.local(2028, 10, 3, 9),
        apply_opens: Time.zone.local(2028, 10, 10, 9),
        first_deadline_banner: Time.zone.local(2029, 7, 12, 9),
        apply_deadline: Time.zone.local(2029, 9, 18, 18),
        find_closes: Time.zone.local(2029, 10, 1).end_of_day,
      },
    }.freeze

    # Every recruitment cycle phase, with the boundaries it runs between and
    # whether the cycle switcher moves the user to the next recruitment cycle.
    # Everything else about a phase is derived from this table. Declared in
    # the order a person actually walks through time — the switcher renders
    # its options in this order too, and emits a divider wherever the cycle
    # year changes between neighbours, so reordering this table reorders the
    # page.
    PHASES = {
      apply_closing_soon: {
        from: ->(year) { first_deadline_banner(year) },
        to: ->(year) { apply_deadline(year) },
        advances_cycle: false,
      },
      today_is_after_apply_deadline_passed: {
        from: ->(year) { apply_deadline(year) },
        to: ->(year) { find_closes(year) },
        advances_cycle: false,
      },
      # The only row that spans two cycle entries, because Find closing and Find
      # reopening are the seam between them. Indexed by the cycle it leads into,
      # which is where `cycle_year_for_time` puts all but a sliver of it.
      find_closed: {
        from: ->(year) { previous_find_closes(year) },
        to: ->(year) { find_opens(year) },
        advances_cycle: true,
      },
      apply_not_open_yet: {
        from: ->(year) { find_opens(year) },
        to: ->(year) { apply_opens(year) },
        advances_cycle: true,
      },
      today_is_after_apply_opens: {
        from: ->(year) { apply_opens(year) },
        to: ->(year) { apply_deadline(year) },
        advances_cycle: true,
      },
    }.freeze

    def self.current_year
      now = Time.zone.now
      current_year = cycle_year_for_time(now)

      # If the cycle switcher has been set to 'apply has reopened' then
      # we want to request next year's courses from the TTAPI
      if PHASES.dig(current_cycle_schedule, :advances_cycle)
        current_year + 1
      else
        current_year
      end
    end

    # Returns the recruitment cycle year for a given time
    #
    # Recruitment Cycles run from the start of the day that find opens
    # to the moment find closes (end of day)
    # Error is raised if a time does not match a listed cycle
    def self.cycle_year_for_time(time)
      CYCLE_DATES.each do |year, dates|
        end_time = CYCLE_DATES[year + 1]&.dig(:find_opens)&.beginning_of_day || dates[:find_closes]&.end_of_day

        return year if time >= dates[:find_opens]&.beginning_of_day && time < end_time
      end

      raise "NoRecruitmentCycleExists: time #{time.to_fs(:db)}"
    end

    # Return the cycle year of last cycle if it's less than 30 days ago
    # Otherwise return nil
    #
    # @returns [year|nil]
    def self.years_available_to_support
      last_year = cycle_year_for_time(30.days.ago)
      last_year if current_year != last_year
    end

    def self.next_year
      current_year + 1
    end

    def self.previous_year
      current_year - 1
    end

    # Whether a cycle year is the current one or the one before it, as opposed
    # to a future cycle. Callers use this to branch on how a cycle behaves —
    # Publish, for one, picks its course status vocabulary from it.
    def self.current_or_previous_year?(year)
      [current_year, previous_year].include?(year.to_i)
    end

    def self.find_closes(year = current_year)
      date(:find_closes, year)
    end

    # When Find last shut before this cycle. The earliest cycle in the table has
    # nothing before it, so its closure starts where the table's knowledge starts.
    def self.previous_find_closes(year)
      return find_opens(year).beginning_of_day unless CYCLE_DATES.key?(year - 1)

      find_closes(year - 1)
    end

    def self.first_deadline_banner(year = current_year) = date(:first_deadline_banner, year)

    def self.apply_deadline(year = current_year)
      date(:apply_deadline, year)
    end

    def self.find_opens(year = current_year)
      date(:find_opens, year)
    end

    def self.find_reopens
      date(:find_opens, next_year)
    end

    # Next date find opens (either this cycle or next)
    # return nil if no date is found
    def self.next_find_opens
      cycle = CYCLE_DATES.values.find do |year|
        year[:find_opens] > Time.zone.now
      end

      return nil if cycle.blank?

      cycle[:find_opens]
    end

    def self.apply_opens(year = current_year)
      date(:apply_opens, year)
    end

    def self.apply_reopens
      date(:apply_opens, next_year)
    end

    def self.mid_cycle(year = current_year)
      date(:find_opens, year) + 2.months
    end

    def self.preview_mode?
      Time.zone.now.between?(apply_deadline, find_closes)
    end

    def self.find_open? = !phase_in_time?(:find_closed)
    def self.find_down? = phase_in_time?(:find_closed)

    # Whether a candidate can start an application for the cycle on display.
    #
    # This spans two phases rather than reading one. Apply accepts a part built
    # application from the moment Find opens, a week before it accepts
    # submissions, so the apply button belongs on the page for both. The two
    # phases differ only in what the page says about the wait, never in what a
    # candidate can do.
    def self.mid_cycle?
      phase_in_time?(:apply_not_open_yet) ||
        phase_in_time?(:today_is_after_apply_opens)
    end

    def self.show_apply_deadline_banner? = phase_in_time?(:apply_closing_soon)

    def self.apply_deadline_passed = phase_in_time?(:today_is_after_apply_deadline_passed)

    def self.show_cycle_closed_banner? = phase_in_time?(:today_is_after_apply_deadline_passed)

    def self.show_apply_opens_soon_banner?
      phase_in_time?(:apply_not_open_yet)
    end

    def self.phase_range(phase, year)
      definition = PHASES.fetch(phase)
      [definition[:from].call(year), definition[:to].call(year)]
    end

    # The hints describe a fixed set of choices, so they read the real cycle year
    # rather than `current_year`, which advances for whichever phase is currently
    # selected and would make the page describe itself.
    #
    # Returns the cycle the option *leads to* if the switcher is set to this
    # phase, not the cycle year the phase itself occurs in.
    def self.year_for_phase(phase, year = cycle_year_for_time(Time.zone.now))
      PHASES.dig(phase, :advances_cycle) ? year + 1 : year
    end

    def self.phases_in_time
      year = current_year

      PHASES.keys.index_with do |phase|
        from, to = phase_range(phase, year)
        Time.zone.now.between?(from, to)
      end
    end

    # A phase turns on every phase whose range contains its own. The switcher
    # picks one phase, so it has to work the containment out for itself. Only
    # one nesting is left: the deadline banner window sits inside the apply
    # window, because it is a banner rather than a separate state.
    def self.implied_phases(phase)
      # Catches :real, and any stale value left in Redis from before the
      # allowlist of phases existed.
      return [phase] unless PHASES.key?(phase)

      year = cycle_year_for_time(Time.zone.now)
      from, to = phase_range(phase, year)

      PHASES.keys.select do |candidate|
        candidate_from, candidate_to = phase_range(candidate, year)
        candidate_from <= from && to <= candidate_to
      end
    end

    def self.phase_in_time?(time_period)
      if current_cycle_schedule == :real
        phases_in_time[time_period]
      else
        implied_phases(current_cycle_schedule).include?(time_period)
      end
    end

    def self.date(name, year = current_year)
      real_schedule_for(year.to_i).fetch(name)
    end

    def self.cycle_year_range(year = current_year)
      "#{year} to #{year + 1}"
    end

    def self.next_cycle_year_range(year = current_year)
      "#{year + 1} to #{year + 2}"
    end

    def self.current_cycle_schedule
      # Make sure this setting only has effect on non-production environments
      return :real if Rails.env.production?

      SiteSetting.cycle_schedule
    end

    def self.real_schedule_for(year = current_year)
      CYCLE_DATES[year]
    end
  end
end

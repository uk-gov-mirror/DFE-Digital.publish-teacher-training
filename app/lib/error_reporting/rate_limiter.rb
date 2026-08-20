module ErrorReporting
  # Keep track of errors reported in Rails.cache.
  # If more than threshold of any error exists then report
  # Always ignore entries older than the window
  #
  # Return true if more than threshold entries exist within the window
  class RateLimiter
    def self.report?(key:, threshold:, window: 1.hour)
      now = Time.zone.now.utc.to_f
      events_key = "error_reporting:events:#{key}"
      cutoff = now - window.to_i

      events = Array(Rails.cache.read(events_key)).select { |timestamp| timestamp > cutoff }
      events << now
      Rails.cache.write(events_key, events, expires_in: window.to_i + 60)

      events.size >= threshold
    rescue StandardError => e
      Rails.logger.tagged("ErrorReporting::RateLimiter") { |l| l.error(e.message) }
      true
    end
  end
end

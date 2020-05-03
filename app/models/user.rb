class User < Base
  has_many :organisation_users
  has_many :organisations, through: :organisation_users

  custom_endpoint :accept_transition_screen, on: :member, request_method: :patch
  custom_endpoint :accept_rollover_screen, on: :member, request_method: :patch
  custom_endpoint :accept_terms, on: :member, request_method: :patch

  def self.member(id)
    new(id: id)
  end

  def self.generate_and_send_magic_link(email)
    MagicLink::GenerateAndSendService.call(email: email, site: site)
  end
end

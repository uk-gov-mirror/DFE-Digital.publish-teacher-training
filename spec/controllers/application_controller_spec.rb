require "rails_helper"

describe ApplicationController, type: :controller do
  before do
    controller.response = response
  end

  describe "#request_login" do
    subject { controller.request_login }

    context "user is unauthenticated" do
      it { should redirect_to sign_in_path }
    end
  end

  context "user is authenticated" do
    let(:user_first_name) { "John" }
    let(:user_last_name) { "Smith" }
    let(:user_email) { "email@example.com" }
    let(:sign_in_user_id) { SecureRandom.uuid }

    let(:user_info) do
      {
        "first_name" => user_first_name,
        "last_name" => user_last_name,
        "email" => user_email,
      }
    end

    let(:payload) do
      {
        email: user_email.to_s,
        sign_in_user_id: sign_in_user_id,
        first_name: user_first_name,
        last_name: user_last_name,
      }
    end

    before do
      allow(Base).to receive(:connection)

      allow(JWT::EncodeService).to receive(:call)
        .with(payload: payload)
        .and_return("anything")
    end

    describe "#authenticate" do
      subject { controller.authenticate }

      context "user_id is not blank" do
        let(:user_id) { 666 }

        before do
          allow(Session).to receive(:create)
          allow(Provider).to receive(:all)
            .and_raise("Could not connect to backend")

          controller.request.session = {
            auth_user: {
              "info" => user_info,
              "user_id" => user_id,
              "uid" => sign_in_user_id,
            },
          }
          controller.authenticate
        end

        it "has performed jwt encoding service" do
          expect(JWT::EncodeService).to have_received(:call)
        end

        it "has not called session create" do
          expect(Session).to_not have_received(:create)
        end

        it "has set user_id" do
          expect(controller.request.session[:auth_user]["user_id"]).to eq user_id
        end

        it "has set provider_count" do
          expect(controller.request.session[:auth_user][:provider_count]).to eq nil
        end

        it "has set accept_terms?" do
          expect(controller.request.session[:auth_user][:accept_terms?]).to eq nil
        end

        describe "sentry contexts" do
          before do
            allow(Raven).to receive(:user_context)
            allow(Raven).to receive(:tags_context)
          end

          it "sets the id in the user context" do
            controller.authenticate

            expect(Raven).to have_received(:user_context).with(id: user_id)
          end

          it "sets the DFE sign-in id in the tags context" do
            controller.authenticate

            expect(Raven).to have_received(:tags_context)
                               .with(sign_in_user_id: sign_in_user_id)
          end
        end

        describe "#log_safe_current_user" do
          it "does not include user email address" do
            expect(controller.log_safe_current_user.to_s).to_not include(user_email)
            expect(controller.log_safe_current_user(reload: true).to_s).to_not include(user_email)
          end

          it "email address is md5 hashed" do
            expect(controller.log_safe_current_user[:email_md5]).to be_eql(Digest::MD5.hexdigest(user_email))
            expect(controller.log_safe_current_user(reload: true)[:email_md5]).to be_eql(Digest::MD5.hexdigest(user_email))
          end

          it "has user_id" do
            expect(controller.log_safe_current_user[:user_id]).to be_eql(user_id)
            expect(controller.log_safe_current_user(reload: true)[:user_id]).to be_eql(user_id)
          end

          it "has sign_in_user_id" do
            expect(controller.log_safe_current_user[:sign_in_user_id]).to be_eql(sign_in_user_id)
            expect(controller.log_safe_current_user(reload: true)[:sign_in_user_id]).to be_eql(sign_in_user_id)
          end
        end
      end

      context "user_id is blank" do
        let(:user_id) { 999 }

        let(:session) do
          {
            id: user_id,
            state: "new",
            admin: true,
            associated_with_accredited_body: false,
            accept_terms_date_utc: Time.zone.now,
            notifications_configured: false,
            first_name: user_first_name,
            last_name: user_last_name,
            email: user_email,
          }
        end

        before do
          allow(Session).to receive(:create)
                              .with(first_name: user_info[:first_name],
                                    last_name: user_info[:last_name])
                              .and_return(
                                double(
                                  **session,
                                  attributes: session,
                                ),
                              )
          allow(Provider).to receive_message_chain(:where, :all)
                               .and_return(%w[one two])

          controller.request.session = {
            auth_user: {
              "info" => user_info,
              "uid" => sign_in_user_id,
            },
          }

          controller.authenticate
        end

        it "has performed jwt encoding service" do
          expect(JWT::EncodeService).to have_received(:call)
        end

        it "has called session create" do
          expect(Session).to have_received(:create)
        end

        it "has set user_id" do
          expect(controller.request.session[:auth_user]["user_id"])
            .to eq user_id
        end

        it "has set admin" do
          expect(controller.request.session[:auth_user]["admin"])
            .to eq true
        end

        it "has set provider_count" do
          expect(controller.request.session[:auth_user][:provider_count])
            .to eq 2
        end

        describe "sentry contexts" do
          before do
            allow(Raven).to receive(:user_context)
            allow(Raven).to receive(:tags_context)
          end

          it "sets the id in the user context" do
            controller.authenticate

            expect(Raven).to have_received(:user_context).with(id: user_id)
          end

          it "sets the DFE sign-in id in the tags context" do
            controller.authenticate

            expect(Raven).to have_received(:tags_context)
                               .with(sign_in_user_id: sign_in_user_id)
          end
        end

        describe "#log_safe_current_user" do
          it "does not include user email address" do
            expect(controller.log_safe_current_user.to_s).to_not include(user_email)
            expect(controller.log_safe_current_user(reload: true).to_s).to_not include(user_email)
          end

          it "email address is md5 hashed" do
            expect(controller.log_safe_current_user[:email_md5]).to be_eql(Digest::MD5.hexdigest(user_email))
            expect(controller.log_safe_current_user(reload: true)[:email_md5]).to be_eql(Digest::MD5.hexdigest(user_email))
          end

          it "has user_id" do
            expect(controller.log_safe_current_user[:user_id]).to be_eql(user_id)
            expect(controller.log_safe_current_user(reload: true)[:user_id]).to be_eql(user_id)
          end

          it "has sign_in_user_id" do
            expect(controller.log_safe_current_user[:sign_in_user_id]).to be_eql(sign_in_user_id)
            expect(controller.log_safe_current_user(reload: true)[:sign_in_user_id]).to be_eql(sign_in_user_id)
          end
        end
      end
    end
  end

  describe "#append_info_to_payload" do
    let(:current_user) do
      {
        user_id: 1,
        uid: SecureRandom.uuid,
      }.with_indifferent_access
    end

    let(:payload) { {} }

    before :each do
      allow(controller).to receive(:current_user).and_return(current_user)
    end

    it "sets the user id in the payload" do
      controller.__send__(:append_info_to_payload, payload)

      expect(payload[:user][:id]).to eq 1
    end

    it "sets the id in the payload to the sign_in id" do
      controller.__send__(:append_info_to_payload, payload)

      expect(payload[:user][:sign_in_user_id]).to eq current_user[:uid]
    end

    it "sets the request_id in the payload to the request uuid" do
      request_uuid = SecureRandom.uuid
      allow(request).to receive(:uuid).and_return(request_uuid)
      controller.__send__(:append_info_to_payload, payload)

      expect(payload[:request_id]).to eq request_uuid
    end
  end

  describe "#store_request_id" do
    it "stores the request id" do
      request_uuid = SecureRandom.uuid

      allow(request).to receive(:uuid).and_return(request_uuid)
      allow(RequestStore).to receive(:store).and_return({})

      controller.__send__(:store_request_id)

      expect(RequestStore.store).to eq(request_id: request_uuid)
    end
  end
end

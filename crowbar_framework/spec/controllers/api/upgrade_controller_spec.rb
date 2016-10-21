require "spec_helper"

describe Api::UpgradeController, type: :request do
  context "with a successful upgrade API request" do
    let(:headers) { { ACCEPT: "application/vnd.crowbar.v2.0+json" } }
    let!(:upgrade_status) do
      JSON.parse(
        File.read(
          "spec/fixtures/upgrade_status.json"
        )
      ).to_json
    end
    let!(:upgrade_prechecks) do
      JSON.parse(
        File.read(
          "spec/fixtures/upgrade_prechecks.json"
        )
      ).to_json
    end
    let!(:crowbar_repocheck) do
      JSON.parse(
        File.read(
          "spec/fixtures/crowbar_repocheck.json"
        )
      ).to_json
    end
    let(:pacemaker) do
      Class.new
    end

    it "shows the upgrade status object" do
      allow(Api::Upgrade).to receive(:network_checks).and_return([])
      allow(Crowbar::Sanity).to receive(:check).and_return([])
      allow(Api::Upgrade).to receive(
        :maintenance_updates_status
      ).and_return({})
      allow(Api::Crowbar).to receive(
        :addons
      ).and_return(["ceph", "ha"])
      stub_const("Api::Pacemaker", pacemaker)
      allow(pacemaker).to receive(
        :ha_presence_check
      ).and_return({})

      get "/api/upgrade", {}, headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(upgrade_status)
    end

    it "updates the upgrade status object" do
      patch "/api/upgrade", {}, headers
      expect(response).to have_http_status(:not_implemented)
    end

    it "prepares the crowbar upgrade" do
      post "/api/upgrade/prepare", {}, headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "stops related services on all nodes during upgrade" do
      allow_any_instance_of(CrowbarService).to receive(
        :prepare_nodes_for_os_upgrade
      ).and_return(true)

      post "/api/upgrade/services", {}, headers
      expect(response).to have_http_status(:ok)
    end

    it "fails to stop related services on all nodes during upgrade" do
      allow_any_instance_of(CrowbarService).to receive(
        :prepare_nodes_for_os_upgrade
      ).and_raise("and Error")

      post "/api/upgrade/services", {}, headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "initiates the upgrade of nodes" do
      allow_any_instance_of(NodeObject).to receive(:run_ssh_cmd).and_return(
        stdout: "",
        tderr: "",
        exit_code: 0
      )
      allow(Api::Upgrade).to receive(:upgrade_controller_nodes).and_return(true)
      allow_any_instance_of(Api::Node).to receive(:upgrade).and_return(true)

      post "/api/upgrade/nodes", {}, headers
      expect(response).to have_http_status(:ok)
    end

    it "initiates the upgrade of nodes and fails" do
      allow_any_instance_of(NodeObject).to receive(:run_ssh_cmd).and_return(
        stdout: "",
        tderr: "",
        exit_code: 1
      )
      allow(Api::Upgrade).to receive(:upgrade_controller_nodes).and_return(false)
      allow_any_instance_of(Api::Node).to receive(:upgrade).and_return(true)

      post "/api/upgrade/nodes", {}, headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "shows a sanity check in preparation for the upgrade" do
      allow(Api::Upgrade).to receive(:network_checks).and_return([])
      allow(::Crowbar::Sanity).to receive(:check).and_return([])
      allow(Api::Upgrade).to receive(
        :maintenance_updates_status
      ).and_return({})
      allow(Api::Crowbar).to receive(
        :addons
      ).and_return(["ha", "ceph"])
      stub_const("Api::Pacemaker", pacemaker)
      allow(pacemaker).to receive(
        :ha_presence_check
      ).and_return({})
      allow(Api::Upgrade).to receive(:checks).and_return(
        JSON.parse(upgrade_prechecks)["checks"].deep_symbolize_keys
      )

      get "/api/upgrade/prechecks", {}, headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(upgrade_prechecks)
    end

    it "cancels the upgrade" do
      allow_any_instance_of(CrowbarService).to receive(
        :revert_nodes_from_crowbar_upgrade
      ).and_return(true)

      post "/api/upgrade/cancel", {}, headers
      expect(response).to have_http_status(:ok)
    end

    it "fails to cancel the upgrade" do
      allow_any_instance_of(CrowbarService).to receive(
        :revert_nodes_from_crowbar_upgrade
      ).and_raise("an Error")

      post "/api/upgrade/cancel", {}, headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq(
        {
          errors: {
            cancel: {
              data: "an Error",
              help: I18n.t("api.upgrade.cancel.help.default")
            }
          }
        }.deep_stringify_keys
      )
    end

    it "checks for node repositories" do
      allow_any_instance_of(NodeObject).to(
        receive(:roles).and_return(["crowbar"])
      )
      allow(NodeObject).to(
        receive(:all).and_return([NodeObject.find_node_by_name("testing")])
      )
      allow(Api::Upgrade).to(
        receive(:target_platform).and_return("suse-12.2")
      )
      allow(Api::Node).to(
        receive(:node_architectures).and_return(
          "os" => ["x86_64"],
          "openstack" => ["x86_64"],
          "ceph" => ["x86_64"],
          "ha" => ["x86_64"]
        )
      )
      allow(::Crowbar::Repository).to(
        receive(:provided_and_enabled?).and_return(true)
      )
      ["os", "ceph", "ha", "openstack"].each do |feature|
        allow(::Crowbar::Repository).to(
          receive(:provided_and_enabled_with_repolist).with(
            feature, "suse-12.2", "x86_64"
          ).and_return([true, {}])
        )
      end

      get "/api/upgrade/noderepocheck", {}, headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(
        "{\"os\":{\"available\":true,\"repos\":{}},\"openstack\":{\"available\":true,\"repos\":{}}}"
      )
    end

    it "checks the crowbar repositories" do
      allow(Api::Upgrade).to(
        receive(:adminrepocheck).and_return(JSON.parse(crowbar_repocheck))
      )

      get "/api/upgrade/adminrepocheck", {}, headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(crowbar_repocheck)
    end
  end
end

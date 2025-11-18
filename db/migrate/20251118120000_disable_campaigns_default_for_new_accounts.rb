class DisableCampaignsDefaultForNewAccounts < ActiveRecord::Migration[7.0]
  def up
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return unless config&.value.present?

    features = config.value.map do |f|
      if f['name'] == 'campaigns'
        f.merge('enabled' => false)
      else
        f
      end
    end

    config.value = features
    config.save!

    GlobalConfig.clear_cache
  end

  def down
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return unless config&.value.present?

    features = config.value.map do |f|
      if f['name'] == 'campaigns'
        f.merge('enabled' => true)
      else
        f
      end
    end

    config.value = features
    config.save!

    GlobalConfig.clear_cache
  end
end



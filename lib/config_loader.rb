class ConfigLoader
  DEFAULT_OPTIONS = {
    config_path: nil,
    reconcile_only_new: true
  }.freeze

  def process(options = {})
    options = DEFAULT_OPTIONS.merge(options)
    # function of the "reconcile_only_new" flag
    # if true,
    #   it leaves the existing config and feature flags as it is and
    #   creates the missing configs and feature flags with their default values
    # if false,
    #   then it overwrites existing config and feature flags with default values
    #   also creates the missing configs and feature flags with their default values
    @reconcile_only_new = options[:reconcile_only_new]

    # setting the config path
    @config_path = options[:config_path].presence
    @config_path ||= Rails.root.join('config')

    # general installation configs
    reconcile_general_config

    # default account based feature configs
    reconcile_feature_config
  end

  def general_configs
    @config_path ||= Rails.root.join('config')
    @general_configs ||= YAML.safe_load_file("#{@config_path}/installation_config.yml").freeze
  end

  private

  def account_features
    @account_features ||= YAML.safe_load_file("#{@config_path}/features.yml").freeze
  end

  def reconcile_general_config
    general_configs.each do |config|
      new_config = config.with_indifferent_access
      existing_config = InstallationConfig.find_by(name: new_config[:name])
      save_general_config(existing_config, new_config)
    end
  end

  def save_general_config(existing, latest)
    if existing
      # save config only if reconcile flag is false and existing configs value does not match default value
      save_as_new_config(latest) if !@reconcile_only_new && compare_values(existing, latest)
    else
      save_as_new_config(latest)
    end
  end

  def compare_values(existing, latest)
    existing.value != latest[:value] ||
      (!latest[:locked].nil? && existing.locked != latest[:locked])
  end

  def save_as_new_config(latest)
    config = InstallationConfig.find_or_initialize_by(name: latest[:name])
    config.value = latest[:value]
    config.locked = latest[:locked]
    config.save!
  end

  def reconcile_feature_config
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')

    if config
      # Garantir que config.value seja sempre um Array
      current_value = Array(config.value)
      return false if current_value == account_features

      compare_and_save_feature(config, current_value)
    else
      save_as_new_config({ name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS', value: account_features, locked: true })
    end
  end

  def compare_and_save_feature(config, current_value)
    # Normalize hashes to have string keys only (avoid HashWithIndifferentAccess and symbol keys)
    normalized_current = normalize_feature_hashes(current_value)
    normalized_account = normalize_feature_hashes(account_features)
    
    features = if @reconcile_only_new
                 # leave the existing feature flag values as it is and add new feature flags with default values
                 (normalized_current + normalized_account).uniq { |h| h['name'] }
               else
                 # update the existing feature flag values with default values and add new feature flags with default values
                 (normalized_account + normalized_current).uniq { |h| h['name'] }
               end
    
    # If save fails due to serialization issues, destroy and recreate
    begin
      config.name = 'ACCOUNT_LEVEL_FEATURE_DEFAULTS'
      config.value = features
      config.locked = true
      config.save!
    rescue TypeError, ArgumentError => e
      Rails.logger.warn("Failed to update ACCOUNT_LEVEL_FEATURE_DEFAULTS due to #{e.class}: #{e.message}. Recreating...")
      config.destroy
      save_as_new_config({ name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS', value: features, locked: true })
    end
  end

  def normalize_feature_hashes(features)
    Array(features).map do |feature|
      # Convert to plain hash with string keys and ensure it's a simple hash
      next feature unless feature.is_a?(Hash)
      
      # Deep convert to plain hash with string keys only
      JSON.parse(feature.to_json)
    end
  end
end

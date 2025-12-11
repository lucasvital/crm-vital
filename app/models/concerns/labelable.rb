module Labelable
  extend ActiveSupport::Concern

  included do
    acts_as_taggable_on :labels
  end

  def update_labels(labels = nil)
    update!(label_list: labels)
  end

  def add_labels(new_labels = nil)
    return if new_labels.blank?

    new_labels = Array(new_labels) # Make sure new_labels is an array
    combined_labels = label_list + new_labels  # Use label_list (array of strings) instead of labels (Tag objects)
    
    Rails.logger.info "=== Labelable: Tentando adicionar labels: #{new_labels.inspect}"
    Rails.logger.info "=== Labelable: Labels atuais: #{label_list.inspect}"
    Rails.logger.info "=== Labelable: Labels combinadas: #{combined_labels.inspect}"
    
    result = update!(label_list: combined_labels)
    
    Rails.logger.info "=== Labelable: Update result: #{result}"
    Rails.logger.info "=== Labelable: Labels após save: #{reload.label_list.inspect}"
    
    result
  rescue StandardError => e
    Rails.logger.error "=== Labelable ERROR: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end

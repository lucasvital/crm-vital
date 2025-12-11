# frozen_string_literal: true

class AddProcessingStatusToCallAnalyses < ActiveRecord::Migration[7.0]
  def change
    add_column :call_analyses, :processing_status, :string, default: 'completed', null: false
    add_column :call_analyses, :processing_error, :text

    add_index :call_analyses, :processing_status
  end
end


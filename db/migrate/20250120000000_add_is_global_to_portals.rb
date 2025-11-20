class AddIsGlobalToPortals < ActiveRecord::Migration[7.1]
  def change
    add_column :portals, :is_global, :boolean, default: false, null: false
    add_index :portals, :is_global
    
    # Permitir account_id null para portais globais
    change_column_null :portals, :account_id, true
  end
end


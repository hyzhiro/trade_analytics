class ChangeUniqueIndexOnTrades < ActiveRecord::Migration[7.2]
  def change
    remove_index :trades, [:statement_id, :ticket], if_exists: true
    add_index :trades, [:account_id, :ticket], unique: true
  end
end



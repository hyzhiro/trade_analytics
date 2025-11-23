class CreateTrades < ActiveRecord::Migration[7.2]
  def change
    create_table :trades do |t|
      t.references :statement, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :ticket, null: false
      t.datetime :open_time
      t.string :trade_type
      t.decimal :size, precision: 12, scale: 2
      t.string :item
      t.decimal :open_price, precision: 20, scale: 6
      t.decimal :sl, precision: 20, scale: 6
      t.decimal :tp, precision: 20, scale: 6
      t.datetime :close_time
      t.decimal :close_price, precision: 20, scale: 6
      t.integer :commission
      t.integer :taxes
      t.integer :swap
      t.integer :profit
      t.timestamps
    end
    add_index :trades, [:statement_id, :ticket], unique: true
  end
end



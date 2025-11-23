class CreateStatements < ActiveRecord::Migration[7.2]
  def change
    create_table :statements do |t|
      t.references :account, null: false, foreign_key: true
      t.datetime :uploaded_at
      t.integer :closed_pl
      t.integer :balance
      t.datetime :raw_generated_at

      t.timestamps
    end
  end
end

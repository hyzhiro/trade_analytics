class CreateAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :accounts do |t|
      t.string :number
      t.string :name
      t.string :currency

      t.timestamps
    end
  end
end

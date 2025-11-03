class CreateTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :tickets do |t|
      t.references :order, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.decimal :price
      t.string :ticket_number

      t.timestamps
    end
  end
end

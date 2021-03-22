class CreateReminderExperiments < ActiveRecord::Migration[5.2]
  def change
    create_table :experiments do |t|
      t.boolean :active, null: false
      t.date :start_date, null: true
      t.date :end_date, null: true
      t.timestamps
    end
  end
end

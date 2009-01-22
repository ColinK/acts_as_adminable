# Install hook code here

begin
  ActiveRecord::Base.connection.select_one("SELECT COUNT(*) FROM adminable_text")
  puts "Table 'adminable_text' exists. Skipping creation step."
rescue

  print "Creating table adminable_text..."
  ActiveRecord::Migration.create_table :adminable_text do |t|
    t.string :content_key
    t.string :data_type
    t.text   :value
    t.timestamps
  end
  ActiveRecord::Migration.add_index(:adminable_text, :content_key, {:unique => true})
  puts "  done"
end
class CreateTopConceptImageTables < ActiveRecord::Migration
  def self.database_model
    return "SpeciesSchemaModel"
  end
  
  def self.up
    execute "CREATE TABLE `top_concept_images` (
                `taxon_concept_id` int(10) unsigned NOT NULL,
                `data_object_id` int(10) unsigned NOT NULL,
                `view_order` smallint(5) unsigned NOT NULL,
                PRIMARY KEY  (`taxon_concept_id`,`data_object_id`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
        
    execute "CREATE TABLE `top_unpublished_concept_images` (
                `taxon_concept_id` int(10) unsigned NOT NULL,
                `data_object_id` int(10) unsigned NOT NULL,
                `view_order` smallint(5) unsigned NOT NULL,
                PRIMARY KEY  (`taxon_concept_id`,`data_object_id`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
  end
  
  def self.down
    drop_table :top_concept_images
    drop_table :top_unpublished_concept_images
  end  
end

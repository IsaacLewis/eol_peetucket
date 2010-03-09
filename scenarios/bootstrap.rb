# Put a few taxa (all within a new hierarchy) in the database with a range of accoutrements
#
#   TODO add a description here of what actually gets created!
#
#   This description block can be viewed (as well as other information 
#   about this scenario) by running:
#     $ rake scenarios:show NAME=bootstrap
#
# ---
# dependencies: [ :foundation ]
# arbitrary_variable: arbitrary value

require 'spec/eol_spec_helpers'
require 'spec/scenario_helpers'
# This gives us the ability to recalculate some DB values:
include EOL::Data
# This gives us the ability to build taxon concepts:
include EOL::Spec::Helpers

# A singleton that creates some users:
def bootstrap_users
  @@bootstrap_users ||= []
  return @@bootstrap_users unless @@bootstrap_users.length == 0
  12.times { @@bootstrap_users << User.gen }
  return @@bootstrap_users
end

# This used to be... random.  Now, I'm creating a small subset of the "real" TocItems.
def bootstrap_toc
  current_order = TocItem.count # Just a reasonable place to start counting for "parent" items.
  description_labels = [
      'Succinct',
      'Diagnosis of genus and species',
      'Physical Description',
      'Formal Description',
      'Molecular Biology and Genetics',
      'Phenology',
      'Life History',
      'Geographical Distribution',
      'Etymology',
      'Adult Characteristics',
      'Comparison with Similar Species',
      'Host, Oviposition, and Larval Feeding Habits',
      'Type',
      'Characteristics',
      'General Description'
  ]
  make_toc_children(TocItem.find_by_label('Description').id, description_labels, current_order)
  current_order += description_labels.length+1
  TocItem.gen(:label => 'Reproductive Behavior', :parent_id => 0, :view_order => current_order += 1)
  TocItem.gen(:label => 'Conservation', :parent_id => 0, :view_order => current_order += 1)
  TocItem.gen(:label => 'Evolution and Systematics', :parent_id => 0, :view_order => current_order += 1)
  TocItem.gen(:label => 'Literature References', :parent_id => 0, :view_order => current_order += 1)
  education = TocItem.gen(:label => 'Education', :parent_id => 0, :view_order => current_order += 1)
  if ii = InfoItem.find_by_label('Education')
    ii.toc_id = education.id
    ii.save
  end
  relevance = TocItem.gen(:label => 'Relevance', :parent_id => 0, :view_order => current_order += 1)
  relevance_labels = [
    'Harmful Blooms',
    'Relation to Humans',
    'Toxicity, Symptoms and Treatment',
    'Cultivation',
    'Culture',
    'Ethnobotany',
    'Suppliers'
  ]
  make_toc_children(relevance.id, relevance_labels, current_order)
end

def make_toc_children(parent_id, labels, current_order)
  labels.each do |label|
    current_order += 1
    TocItem.gen(:label => label, :parent_id => parent_id, :view_order => current_order)
  end
end


#### Real work begins

bootstrap_toc

Rails.cache.clear # We appear to be altering some of the cached classes here.  JRice 6/26/09

# TODO - I am neglecting to set up agent content partners, curators, contacts, provided data types, or agreements.  For now.
agent_col = Agent.catalogue_of_life
resource = Resource.gen(:title => 'Bootstrapper', :resource_status => ResourceStatus.published)
event    = HarvestEvent.gen(:resource => resource)
AgentsResource.gen(:agent => agent_col, :resource => resource,
                   :resource_agent_role => ResourceAgentRole.content_partner_upload_role)

gbif_agent = Agent.gen(:full_name => "Global Biodiversity Information Facility (GBIF)")
#gbif_agent = Agent.find_by_full_name('Global Biodiversity Information Facility (GBIF)');
gbif_cp    = ContentPartner.gen :vetted => true, :agent => gbif_agent
AgentContact.gen(:agent => gbif_agent, :agent_contact_role => AgentContactRole.primary)
gbif_hierarchy = Hierarchy.gen(:agent => gbif_agent, :label => "GBIF Nub Taxonomy")

kingdom = build_taxon_concept(:rank => 'kingdom', :canonical_form => 'Animalia', :event => event)
kingdom.add_common_name_synonym('Animals', agent_col, :language => Language.english)

4.times do
  tc = build_taxon_concept(:parent_hierarchy_entry_id => Hierarchy.default.hierarchy_entries.last.id,
                           :depth => Hierarchy.default.hierarchy_entries.length,
                           :event => event)
  tc.add_common_name_synonym(Factory.next(:common_name), agent_col, :language => Language.english)
end

fifth_entry_id = Hierarchy.default.hierarchy_entries.last.id
depth_now      = Hierarchy.default.hierarchy_entries.length

# NOTE!  I am going to use HARDCODED common names *JUST* so that searching will have multiple results for one string.

# Sixth Taxon should have more images, and have videos:
tc = build_taxon_concept(:parent_hierarchy_entry_id => fifth_entry_id,
                         :depth => depth_now, :images => :testing, :event => event)
tc.add_common_name_synonym('Tiger moth', agent_col, :language => Language.english)

#TODO: omg this is HORRIBLE!
u = User.gen
u.vetted = false
tc.current_user = u
tc.images.first.comments[0].body = 'First comment'
tc.images.first.comments[0].save!
tc.images.first.comment(u, 'Second comment')
tc.images.first.comment(u, 'Third comment')
tc.images.first.comment(u, 'Forth comment')
tc.images.first.comment(u, 'Fifth comment')
tc.images.first.comment(u, 'Sixth comment')
tc.images.first.comment(u, 'Seventh comment')
tc.images.first.comment(u, 'Eighth comment')
tc.images.first.comment(u, 'Nineth comment')
tc.images.first.comment(u, 'Tenth comment')
tc.images.first.comment(u, 'Eleventh comment')
tc.images.first.comment(u, 'Twelveth comment')

# Seventh Taxon (sign of the apocolypse?) should be a child of fifth and be "empty", other than common names:
tc = build_taxon_concept(:parent_hierarchy_entry_id => fifth_entry_id,
                         :depth => depth_now, 
                         :images => [], 
                         :toc => [], 
                         :flash => [], 
                         :youtube => [], 
                         :comments => [],
                         :bhl => [], 
                         :event => event,
                         :vetted => 'untrusted')
tc.add_common_name_synonym('Tiger lilly', agent_col, :language => Language.english)

# Eighth Taxon (now we're just getting greedy) should be the same as Seven, but with BHL:
tc = build_taxon_concept(:parent_hierarchy_entry_id => fifth_entry_id,
                         :depth => depth_now, 
                         :images => [], 
                         :toc => [], 
                         :flash => [], 
                         :youtube => [], 
                         :comments => [],
                         :event => event,
                         :vetted => 'unknown')
tc.add_common_name_synonym('Tiger', agent_col, :language => Language.english)

# Ninth Taxon is *totally* naked:
build_taxon_concept(:parent_hierarchy_entry_id => fifth_entry_id, :common_names => [], :bhl => [], :event => event,
                    :depth => depth_now, :images => [], :toc => [], :flash => [], :youtube => [], :comments => [])

#30 has unvetted images and videos, overview and description TOC, please don't change this one, needed for selenum tests:         
tc30 = build_taxon_concept(:id => 30, 
                    :parent_hierarchy_entry_id => fifth_entry_id,
                    :depth    => depth_now, 
                    :images   => :testing, 
                    :flash    => [{:vetted   => Vetted.untrusted}], 
                    :youtube  => [{:vetted   => Vetted.untrusted}], 
                    :comments => [], 
                    :bhl      => [], 
                    :event    => event)
                    
tc30.add_common_name_synonym(Factory.next(:common_name), agent_col, :language => Language.english)
curator = build_curator(tc30, :username => 'test_curator', :password => 'password', :given_name => 'test', :family_name => 'curator') 

#31 has unvetted and vetted videos, please don't change this one, needed for selenum test:         
overv = TocItem.find_by_label('Overview')
desc = TocItem.find_by_label('Description')
tc31 = build_taxon_concept(:parent_hierarchy_entry_id => fifth_entry_id, :common_names => [Factory.next(:common_name)], :id => 31, 
                  :depth => depth_now, 
                  :flash => [{}, {:vetted => Vetted.unknown}], 
                  :youtube => [{:vetted => Vetted.unknown}, 
                               {:vetted => Vetted.untrusted}], 
                  :comments => [],
                  :bhl => [], 
                  :event => event, 
                  :toc => [{
                    :toc_item => overv, 
                    :description => 'overview text for re-harvest'
                    }, 
                    {
                    :toc_item => desc, 
                    :description => 'description text for re-harvest'
                    }],
                  :images => [{
                    :description => '1st image description for re-harvest'
                    }]
)
                    
curator_for_tc31 = build_curator(tc31, :username => 'curator_for_tc', :password => 'password') 

text_dato = tc31.overview.first # TODO - this doesn't seem to ACTAULLY be the overview.  Fix it?
image_dato = tc31.images.first
# rating of old version of dato was 1
text_dato.rate(curator_for_tc31, 1)
image_dato.rate(curator_for_tc31, 1)
# create new dato with the same guid and comments on new version
add_comments_and_tags_to_reharvested_data_objects(tc31)
                    
#32
user = User.gen
overv = TocItem.find_by_label('Overview')
desc = TocItem.find_by_label('Description')
tc = build_taxon_concept(:id => 32, :toc => [{:toc_item => overv}, {:toc_item => overv}, {:toc_item => desc}], :comments => [{}])
description_dato = tc.content_by_category(desc)[:data_objects].first
description_dato.comment(user, 'First comment')
description_dato.comment(user, 'Second comment')  
description_dato.comment(user, 'Third comment')
description_dato.comment(user, 'Forth comment')
description_dato.comment(user, 'Fifth comment')
description_dato.comment(user, 'Sixth comment')
description_dato.comment(user, 'Seventh comment')
description_dato.comment(user, 'Eighth comment')
description_dato.comment(user, 'Ninth comment')
description_dato.comment(user, 'Tenth comment')
description_dato.comment(user, 'Eleventh comment')
description_dato.comment(user, 'Twelfth comment')

DataObjectsInfoItem.gen(:data_object => tc.overview.first, :info_item => InfoItem.find(:first, :order => 'rand()'))
DataObjectsInfoItem.gen(:data_object => tc.overview.last, :info_item => InfoItem.find_by_label("Distribution"))



# create a content_partner that we can log in as for testing (user:password = testcp:testcp)
a = Agent.gen(:username => 'testcp', :password => 'testcp', :password_confirmation => 'testcp', :full_name => 'Test Content Partner', :display_name => 'Test Content Partner')
ac = AgentContact.gen(:agent => a, :agent_contact_role => AgentContactRole.primary)
cp = ContentPartner.gen(:agent => a,
                        :partner_seen_step => '2009-10-21 10:00:00',
                        :partner_complete_step => '2009-10-21 10:00:00',
                        :contacts_seen_step => '2009-10-21 10:00:00',
                        :contacts_complete_step => '2009-10-21 10:00:00',
                        :licensing_seen_step => '2009-10-21 10:00:00',
                        :licensing_complete_step => '2009-10-21 10:00:00',
                        :attribution_seen_step => '2009-10-21 10:00:00',
                        :attribution_complete_step => '2009-10-21 10:00:00',
                        :roles_seen_step => '2009-10-21 10:00:00',
                        :roles_complete_step => '2009-10-21 10:00:00',
                        :transfer_overview_seen_step => '2009-10-21 10:00:00',
                        :transfer_overview_complete_step => '2009-10-21 10:00:00',
                        :transfer_upload_seen_step => '2009-10-21 10:00:00',
                        :transfer_upload_complete_step => '2009-10-21 10:00:00',
                        :specialist_overview_seen_step => '2009-10-21 10:00:00',
                        :specialist_overview_complete_step => '2009-10-21 10:00:00',
                        :specialist_formatting_seen_step => '2009-10-21 10:00:00',
                        :specialist_formatting_complete_step => '2009-10-21 10:00:00',
                        :description => 'description of the partner',
                        :ipr_accept => true,
                        :attribution_accept => true,
                        :roles_accept => true,
                        :transfer_schema_accept => true,
                        :auto_publish => false,
                        :vetted => true)



# Now that we're done with CoL, we add another content partner who overlaps with them:
       # Give it a new name:
name   = Name.gen(:canonical_form => tc.canonical_form_object, :string => n = Factory.next(:scientific_name),
                  :italicized     => "<i>#{n}</i> #{Factory.next(:attribution)}")
agent2 = Agent.gen :username => 'test_cp'
cp     = ContentPartner.gen :vetted => true, :agent => agent2
cont   = AgentContact.gen :agent => agent2, :agent_contact_role => AgentContactRole.primary
r2     = Resource.gen(:title => 'Test ContentPartner import', :resource_status => ResourceStatus.processed)
ev2    = HarvestEvent.gen(:resource => r2)
ar     = AgentsResource.gen(:agent => agent2, :resource => r2, :resource_agent_role => ResourceAgentRole.content_partner_upload_role)
hier   = Hierarchy.gen :agent => agent2
he     = build_hierarchy_entry 0, tc, name, :hierarchy => hier
img    = build_data_object('Image', "This should only be seen by ContentPartner #{cp.description}",
                           :taxon => tc.images.first.taxa[0],
                           :hierarchy_entry => he,
                           :object_cache_url => Factory.next(:image),
                           :vetted => Vetted.unknown,
                           :visibility => Visibility.preview)

# Some node in the GBIF Hierarchy to test maps on
build_hierarchy_entry 0, tc, name, :hierarchy => gbif_hierarchy, :identifier => '13810203'

# Generate a default admin user and then set them up for the default roles:
admin = User.gen :username => 'admin', :password => 'admin', :given_name => 'Admin', :family_name => 'User'
admin.roles = Role.find(:all, :conditions => 'title LIKE "Administrator%"')
admin.save

#user for selenium tests
test_user2 = User.gen(:username => 'test_user2', :password => 'password', :given_name => 'test', :family_name => 'user2')
test_user2.save

#moderator for selenium test
moderator = User.gen :username => 'moderator', :password => 'moderator', :given_name => 'Moderator', :family_name => 'User'
moderator.roles = Role.find(:all, :conditions => 'title LIKE "Moderator"')
moderator.save

exemplar = build_taxon_concept(:id => 910093, # That ID is one of the (hard-coded) exemplars.
                               :event => event,
                               :common_names => ['wumpus', 'wompus', 'wampus'],
                               :biomedical_terms => true) # LigerCat powers, ACTIVATE!

# Adds a ContentPage at the following URL: http://localhost:3000/content/page/curator_central

ContentPage.gen(:page_name => "curator_central", :title => "Curator central", :left_content => "")

col_collection = Collection.gen(:agent => Agent.catalogue_of_life, :title => "Catalogue of Life Collection", :uri => "http://www.catalogueoflife.org/browse_taxa.php?selected_taxon=FOREIGNKEY", :logo_cache_url => 413000)
col_mapping    = Mapping.gen(:collection => col_collection, :name => kingdom.entry.name_object)

# TODO - we need to build TopImages such that ancestors contain the images of their descendants

# creating collection / mapping data
image_collection_type = CollectionType.gen(:label => "Images")
specimen_image_collection_type = CollectionType.gen(:label => "Specimen", :parent_id => image_collection_type.id)
natural_image_collection_type = CollectionType.gen(:label => "Natural", :parent_id => image_collection_type.id)

species_pages_collection_type = CollectionType.gen(:label => "Species Pages")
molecular_species_pages_collection_type = CollectionType.gen(:label => "Molecular", :parent_id => species_pages_collection_type.id)
novice_pages_collection_type = CollectionType.gen(:label => "Novice", :parent_id => species_pages_collection_type.id)
expert_pages_collection_type = CollectionType.gen(:label => "Expert", :parent_id => species_pages_collection_type.id)

marine_theme_collection_type = CollectionType.gen(:label => "Marine")
bugs_theme_collection_type = CollectionType.gen(:label => "Bugs")

name = kingdom.entry.name_object

specimen_image_collection = Collection.gen(:title => 'AntWeb', :description => 'Currently AntWeb contains information on the ant faunas of several areas in the Nearctic and Malagasy biogeographic regions, and global coverage of all ant genera.', :uri => 'http://www.antweb.org/specimen.do?name=FOREIGNKEY', :link => 'http://www.antweb.org/', :logo_cache_url => '781000')
CollectionTypesCollection.gen(:collection => specimen_image_collection, :collection_type => specimen_image_collection_type)
CollectionTypesCollection.gen(:collection => specimen_image_collection, :collection_type => expert_pages_collection_type)
CollectionTypesCollection.gen(:collection => specimen_image_collection, :collection_type => bugs_theme_collection_type)
Mapping.gen(:collection => specimen_image_collection, :name => name, :foreign_key => 'casent0129891')
Mapping.gen(:collection => specimen_image_collection, :name => name, :foreign_key => 'casent0496198')
Mapping.gen(:collection => specimen_image_collection, :name => name, :foreign_key => 'casent0179524')

molecular_species_pages_collection = Collection.gen(
  :title => 'National Center for Biotechnology Information',
  :description => 'Established in 1988 as a national resource for molecular biology information, NCBI creates public databases, conducts research in computational biology, develops software tools for analyzing genome data, and disseminates biomedical information - all for the better understanding of molecular processes affecting human health and disease',
  :uri => 'http://www.ncbi.nlm.nih.gov/sites/entrez?Db=genomeprj&cmd=ShowDetailView&TermToSearch=FOREIGNKEY',
  :link => 'http://www.ncbi.nlm.nih.gov/',
  :logo_cache_url => '130500')
CollectionTypesCollection.gen(:collection => molecular_species_pages_collection, :collection_type => molecular_species_pages_collection_type)
CollectionTypesCollection.gen(:collection => molecular_species_pages_collection, :collection_type => marine_theme_collection_type)
Mapping.gen(:collection => molecular_species_pages_collection, :name => name, :foreign_key => '13646')
Mapping.gen(:collection => molecular_species_pages_collection, :name => name, :foreign_key => '9551')

r = Rank.gen(:label => 'superkingdom', :rank_group_id => 0)

### Adding another hierarchy to test switching from one to another
AgentContact.gen(:agent => Agent.ncbi, :agent_contact_role => AgentContactRole.primary)

eukaryota = build_taxon_concept(:rank => 'superkingdom',
                                :canonical_form => 'Eukaryota',
                                :common_names => ['eukaryotes'],
                                :event => event,
                                :hierarchy => Hierarchy.ncbi,
                                :depth => 0)

opisthokonts_name   = Name.gen(:canonical_form => cf = CanonicalForm.gen(:string => 'Metazoa'),
                  :string => 'Metazoa',
                  :italicized => '<i>Metazoa</i>')
opisthokonts_common_name   = Name.gen(:canonical_form => cf = CanonicalForm.gen(:string => 'opisthokonts'),
                  :string => 'opisthokonts',
                  :italicized => '<i>opisthokonts</i>')
opisthokonts = build_hierarchy_entry(0, kingdom, opisthokonts_name,
            :rank_id => Rank.find_by_label('kingdom').id,
            :identifier => 33154,
            :parent_id => Hierarchy.ncbi.hierarchy_entries.last.id,
            :hierarchy => Hierarchy.ncbi )
TaxonConceptName.gen(:preferred => true, :vern => true, :source_hierarchy_entry_id => opisthokonts.id,
                     :language => Language.english, :name => opisthokonts_common_name, :taxon_concept => kingdom)
TaxonConceptName.gen(:preferred => true, :vern => false, :source_hierarchy_entry_id => opisthokonts.id,
                     :language => Language.scientific, :name => opisthokonts_name, :taxon_concept => kingdom)

4.times do
  parent_id = Hierarchy.ncbi.hierarchy_entries.last.id
  depth = Hierarchy.ncbi.hierarchy_entries.last.depth + 1
  
  2.times do
    sci_name = Factory.next(:scientific_name)
    c_name = Factory.next(:common_name)
    build_taxon_concept(:rank => '',
                        :canonical_form => sci_name,
                        :common_names => [c_name],
                        :event => event,
                        :hierarchy => Hierarchy.ncbi,
                        :parent_hierarchy_entry_id => parent_id,
                        :depth => depth)
  end

end


bacteria = build_taxon_concept(:rank => 'superkingdom',
                                :canonical_form => 'Bacteria',
                                :event => event,
                                :hierarchy => Hierarchy.ncbi,
                                :depth => 0)

# We need to be able to test changing the preferred name across several languages:
english = Language.english
bacteria.add_common_name_synonym("bacteria", agent_col, :language => english, :preferred => true)
bacteria.add_common_name_synonym("bugs", agent_col, :language => english, :preferred => false)
bacteria.add_common_name_synonym("grime", agent_col, :language => english, :preferred => false)
bacteria.add_common_name_synonym("critters",agent_col, :language => english, :preferred => false)
german  = Language.gen(:label => 'German', :iso_639_1 => 'de')
bacteria.add_common_name_synonym("bakteria",agent_col, :language => german, :preferred => true)
bacteria.add_common_name_synonym("die buggen",agent_col, :language => german, :preferred => false)
bacteria.add_common_name_synonym("das greim",agent_col, :language => german, :preferred => false)
french = Language.find_by_label('French') # Assumes French was defined in foundation
bacteria.add_common_name_synonym("baseteir",agent_col, :language => french, :preferred => true)
bacteria.add_common_name_synonym("le grimme",agent_col, :language => french, :preferred => false)
bacteria.add_common_name_synonym("ler petit bugge",agent_col, :language => french, :preferred => false)

bacteria.add_scientific_name_synonym('microbia')

# Another Selenium curator
curator2 = build_curator(bacteria, :username => 'curator_two', :password => 'iliketocurate') 

4.times do
  parent_id = Hierarchy.ncbi.hierarchy_entries.last.id
  depth = Hierarchy.ncbi.hierarchy_entries.last.depth + 1
  
  sci_name = Factory.next(:scientific_name)
  c_name = Factory.next(:common_name)
  build_taxon_concept(:rank => '',
                      :canonical_form => sci_name,
                      :common_names => [c_name],
                      :event => event,
                      :hierarchy => Hierarchy.ncbi,
                      :parent_hierarchy_entry_id => parent_id,
                      :depth => depth)
end

TaxonConcept.all.each do |tc|
  if tc.hierarchy_entries.empty?
    TaxonConcept.delete(tc.id)
  end
end

RandomHierarchyImage.all.each do |rhi|
  d = DataObject.find(rhi.data_object_id)
  Comment.find_all_by_parent_type_and_parent_id('DataObject',d.id).each do |c|
    c.destroy
  end
  d.destroy
  rhi.destroy
end

HierarchyEntry.all.each do |he|
  RandomHierarchyImage.gen(:hierarchy => he.hierarchy, :taxon_concept => he.taxon_concept, :hierarchy_entry => he, :data_object => he.taxon_concept.images[0]) if !he.taxon_concept.images[0].nil?
end

make_all_nested_sets
rebuild_collection_type_nested_set

DataObject.find(:all).each_with_index do |d,i|
  d.created_at = Time.now - i.hours
  d.save!
end

Comment.find(:all).each_with_index do |c,i|
  c.created_at = Time.now - i.hours
  c.save!
end

(-12..12).each do |n|
  date = n.month.ago
  year = date.year
  month = date.month
  GoogleAnalyticsPartnerSummary.gen(:year => year, :month => month, :agent => Agent.catalogue_of_life)
  GoogleAnalyticsSummary.gen(:year => year, :month => month)  
  GoogleAnalyticsPageStat.gen(:year => year, :month => month, :taxon_concept => tc30 )    
  GoogleAnalyticsPartnerTaxon.gen(:year => year, :month => month, :taxon_concept => tc30, :agent => Agent.catalogue_of_life )
end



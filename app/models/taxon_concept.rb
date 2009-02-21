# Represents the vague idea of a Taxon.
#
# We get different interpretations of taxa from our partners (ContentPartner), often differing slightly 
# and referring to basically the same thing, so TaxonConcept was created as a means to reconcile the 
# variant definitions of what are essentially the same Taxon. We currently store basic Taxon we receive
# from data imports in the +taxa+ table and we also store taxonomic hierarchies (HierarchyEntry) in the 
# +hierarchy_entries+ table. Currently TaxonConcept are groups of one or many HierarchyEntry. We will 
# eventually create hierarchy_entries for each entry in the taxa table (Taxon).
#
# It is worth mentioning that the "eol.org/page/nnnn" route is a misnomer.  Those IDs are, for the
# time-being, pointing to TaxonConcepts.
#
# See the comments at the top of the Taxon for more information on this.
# I include there a basic biological definition of what a Taxon is.
#
class TaxonConcept < SpeciesSchemaModel

  #TODO belongs_to :taxon_concept_content

  has_many :hierarchy_entries
  has_many :taxon_concept_names
  has_many :comments, :as => :parent, :attributes => true
  has_many :names, :through => :taxon_concept_names
  # The following are not (yet) possible, because tcn has a three-part Primary key.
  # has_many :taxa, :through => :names, :source => :taxon_concept_names
  # has_many :mappings, :through => :names, :source => :taxon_concept_names

  # These are methods that are specific to a hierarchy, so we have to handle them through entry:
  delegate :kingdom, :to => :entry
  delegate :children, :to => :entry
  delegate :children_hash, :to => :entry
  delegate :ancestors_hash, :to => :entry
  delegate :find_default_hierarchy_ancestor, :to => :entry
  
  has_one :taxon_concept_content

  #delegate :content_level, :to => :entry # TODO remove this
  #TODO delegate :content_level, :to => :taxon_concept_content

  attr_accessor :includes_unvetted # true or false indicating if this taxon concept has any unvetted/unknown data objects

  def name(detail_level = :middle, language = Language.english, context = nil)
    default_hierarchy_id = Hierarchy.default.id rescue nil
    col_he = hierarchy_entries.detect {|he| he.hierarchy_id == default_hierarchy_id }
    return col_he.nil? ? alternate_classification_name(detail_level, language, context).firstcap : col_he.name(detail_level, language, context).firstcap
  end

  def alternate_classification_name(detail_level = :middle, language = Language.english, context = nil)
    #return col_he.nil? ? alternate_classification_name(detail_level, language, context) : col_he.name(detail_level, language, context)
    self.hierarchy_entries[0].name(detail_level, language, context).firstcap rescue '?-?'
  end

  def in_hierarchy(search_hierarchy_id = 0)
    enries = hierarchy_entries.detect {|he| he.hierarchy_id == search_hierarchy_id }
    return enries.nil? ? false : true
  end

  # Because nested has_many_through won't work with CPKs:
  # Also, so we can include collection.
  def mappings
    return @mappings unless @mappings.nil?
    @mappings = Mapping.find_by_sql("SELECT DISTINCT m.id, m.collection_id, m.name_id, m.foreign_key FROM taxon_concept_names tcn JOIN mappings m ON (tcn.name_id=m.name_id) JOIN collections c ON (m.collection_id=c.id) JOIN agents a ON (c.agent_id=a.id) WHERE tcn.taxon_concept_id = #{id} GROUP BY c.id")
    return @mappings = @mappings.sort_by {|m| m.id }.uniq
  end

  # I chose not to make this singleton since it should really only ever get called once:
  def ping_host_urls
    host_urls = []
    mappings.each do |mapping|
      host_urls << mapping.ping_host_url unless mapping.collection.nil? or mapping.ping_host? == false 
    end
    return host_urls
  end

  def approved_curators
    approved = Set.new
    self.hierarchy_entries.each do |he|
      approved.merge he.approved_curators
    end
    return approved
  end

  def hierarchy_entries_with_parents
    HierarchyEntry.with_parents self
  end
  alias hierarchy_entries_with_ancestors hierarchy_entries_with_parents

  def has_citation?
    return false
  end

  # TODO = $MAX_IMAGES_PER_PAGE really should BE an int.
  def more_images
    return @length_of_images > $MAX_IMAGES_PER_PAGE.to_i if @length_of_images
    return images.length > $MAX_IMAGES_PER_PAGE.to_i # This is expensive.  I hope you called #images first!
  end

  def more_videos 
    return @length_of_videos > $MAX_IMAGES_PER_PAGE.to_i if @length_of_videos
    return videos.length > $MAX_IMAGES_PER_PAGE.to_i # This is expensive.  I hope you called #videos first!
  end

  def videos
    videos = DataObject.for_taxon(self, :video, :agent => @current_agent, :user => @current_user)
    @length_of_videos = videos.length # cached, so we don't have to query this again.
    return videos
  end 

  def map
    # NOTE: there may be more than one map, but we only need one.
    DataObject.for_taxon(self, :map, :agent => @current_agent, :user => @current_user)[0]
  end

  # Singleton method to fetch the Hierarchy Entry, used for taxonomic relationships
  def entry(hierarchy = Hierarchy.default)
    hierarchy_id = hierarchy.id rescue nil
    return hierarchy_entries.detect{ |he| he.hierarchy_id == hierarchy_id } || hierarchy_entries[0] || raise(Exception.new("Taxon concept must have at least one hierarchy entry"))
  end

  # We do have some content that is specific to COL, so we need a method that will ALWAYS reference it:
  def col_entry
    return @col_entry unless @col_entry.nil?
    hierarchy_id = Hierarchy.default.id
    return @col_entry = hierarchy_entries.detect{ |he| he.hierarchy_id == hierarchy_id }
  end

  def current_user=(user)
    @current_user ||= user
  end

  def current_agent=(agent)
    @current_agent ||= agent
  end
  
  def available_media
    images = video = map = false
    for entry in hierarchy_entries
      images = true if entry.hierarchies_content.image != 0 || entry.hierarchies_content.child_image != 0 rescue images
      video = true if entry.hierarchies_content.flash != 0 || entry.hierarchies_content.youtube != 0 rescue video
      map = true if entry.hierarchies_content.gbif_image != 0 rescue map
    end
    
    {:images => images,
     :video  => video,
     :map    => map }
  end

  # def available_media
  #   {:images => hierarchies_content.image != 0 || hierarchies_content.child_image  != 0,
  #    :video  => hierarchies_content.flash != 0 || hierarchies_content.youtube != 0,
  #    :map    => hierarchies_content.gbif_image != 0}
  #   
  #   #return entry.media
  # end

  def has_name?
    return content_level != 0
  end

  # TODO - stop calling these.
  def common_name
    return name(:middle)
  end
  def scientific_name
    tcn = taxon_concept_names.select {|n| n.vern == 0 && n.preferred == 1 && !n.name.nil? }.detect { |n| n.source_hierarchy_entry_id = entry.id }
    puts "TCN name id: #{tcn.name_id}"
    return tcn.nil? ? name(:expert) : tcn.name.string
  end
  def canonical_form
    return name(:canonical)
  end
  
  def quick_common_name(language = nil)
    language ||= (@current_user.nil? ? Language.english : @current_user.language) || Language.english
    common_name_results = SpeciesSchemaModel.connection.select_values("SELECT n.string FROM taxon_concept_names tcn JOIN names n ON (tcn.name_id=n.id) WHERE tcn.taxon_concept_id=#{id} AND language_id=#{language.id} AND preferred=1 LIMIT 1")
    if common_name_results.empty?
      return ""
    end
    
    common_name_results[0].firstcap
  end
  
  def quick_scientific_name(type = :normal)
    scientific_name_results = []
    # TODO - refactor this.  Duplication where italicized, but I think all four queries could be generalized.
    case type
      when :normal      then scientific_name_results = SpeciesSchemaModel.connection.execute("SELECT n.string name, he.hierarchy_id source_hierarchy_id FROM taxon_concept_names tcn JOIN names n ON (tcn.name_id=n.id) LEFT JOIN hierarchy_entries he ON (tcn.source_hierarchy_entry_id=he.id) WHERE tcn.taxon_concept_id=#{id} AND vern=0 AND preferred=1").all_hashes
      when :italicized  then scientific_name_results = SpeciesSchemaModel.connection.execute("SELECT n.italicized name, he.hierarchy_id source_hierarchy_id FROM taxon_concept_names tcn JOIN names n ON (tcn.name_id=n.id) LEFT JOIN hierarchy_entries he ON (tcn.source_hierarchy_entry_id=he.id) WHERE tcn.taxon_concept_id=#{id} AND vern=0 AND preferred=1").all_hashes
      when :canonical   then scientific_name_results = SpeciesSchemaModel.connection.execute("SELECT cf.string name, he.hierarchy_id source_hierarchy_id FROM taxon_concept_names tcn JOIN names n ON (tcn.name_id=n.id) JOIN canonical_forms cf ON (n.canonical_form_id=cf.id) LEFT JOIN hierarchy_entries he ON (tcn.source_hierarchy_entry_id=he.id) WHERE tcn.taxon_concept_id=#{id} AND vern=0 AND preferred=1").all_hashes
    end
    
    scientific_name = ""
    
    # This loop is to check to make sure the default hierarchy's preferred name takes precedence over other hierarchy's preferred names 
    scientific_name_results.each_with_index do |result, i|
      if scientific_name=="" || result['source_hierarchy_id'].to_i == Hierarchy.default.id
        scientific_name = result['name'].firstcap
      end
    end
    
    scientific_name
  end
  
  # Some TaxonConcepts are "superceded" by others, and we need to follow the chain as far as we can (up to a sane limit): 
  def self.find_with_supercedure(*args)
    concept = TaxonConcept.find_without_supercedure(*args)
    return nil if concept.nil?
    id = args[0]
    return concept unless id =~ /^\d+$/
    attempts = 6
    while concept.supercedure_id != 0 and attempts <= 6
      concept = TaxonConcept.find_without_supercedure(concept.supercedure_id, *args[1..-1])
      attempts += 1
    end
    return concept
  end
  class << self; alias_method_chain :find, :supercedure ; end

  def self.quick_search(search_string, options = {})
    # TODO - we have qualifier, scope, and search_lang diabled for now, so I am ignoring them entirely.
    options[:qualifier]       ||= 'contains'
    options[:scope]           ||= 'all'
    options[:search_language] ||= 'all'
    
    # TODO - insert into search terms, popular searches, and the like.
    
    # TODO - I'm not sure this is really what we want to be doing, here: I simply reproduced Patrick's code (for the most part).
    search_terms = search_string.downcase.gsub(/\s+/, ' ').strip.split(/[ -&:\\'?;]+| and /)
    
    sci_concepts  = []
    com_concepts  = []
    errors       = nil
    num_matches  = {}
    
    
    modified_search_terms = []
    search_terms.uniq.each do |orig_term|
      term = orig_term.gsub(/\*/, 'EOL_WILDCARD').gsub(/[\W\-]/, '').gsub('EOL_WILDCARD', '%')
      if term.gsub('%', '').length < 3
        errors ||= []
        errors << "All search terms must contain at least three characters. '#{orig_term}' is too short."
      end
      
      search_type = term.match(/%/) ? 'LIKE' : '='
      
      modified_search_terms << "nn.name_part #{search_type} '#{term}'"
    end
    
    
    if modified_search_terms.length == 0 
      return {:common     => com_concepts,
              :scientific => sci_concepts,
              :errors     => errors}
    end
    
    name_ids = SpeciesSchemaModel.connection.select_values("SELECT name_id, count(*) FROM normalized_names nn STRAIGHT_JOIN normalized_links nl ON (nn.id=nl.normalized_name_id) WHERE (#{modified_search_terms.join(' OR ')}) AND nl.normalized_qualifier_id=1 GROUP BY name_id HAVING count(*)>=#{modified_search_terms.length}")
    
    if name_ids.length == 0 
      return {:common     => com_concepts,
              :scientific => sci_concepts,
              :errors     => errors}
    end
    
    
    agent_clause = ''
    if !options[:agent].nil? || (!options[:user].nil? && options[:user].is_admin?)
      agent_clause = "LEFT JOIN (agents_resources ar JOIN hierarchies_resources hr ON (ar.resource_id=hr.resource_id AND ar.resource_agent_role_id = #{ResourceAgentRole.content_partner_upload_role.id}) JOIN hierarchy_entries he2 ON (hr.hierarchy_id=he2.hierarchy_id)) ON (he2.taxon_concept_id=tc.id)"
    end
    
    vetted_condition = options[:user].vetted ? "(published=1 AND tc.vetted_id=#{Vetted.trusted.id})" : "published=1"
    agent_condition =  options[:agent].nil? ? '' : "OR ar.agent_id=#{options[:agent].id}"
    if !options[:user].nil? && options[:user].is_admin?
      agent_condition = "OR ar.agent_id IS NOT NULL"
    end
    
    taxon_concept_ids = SpeciesSchemaModel.connection.execute("SELECT tcn.taxon_concept_id id, tcn.vern is_vern, tcn.preferred preferred, tcc.content_level content_level, n.string matching_string, n.italicized matching_italicized_string, he.hierarchy_id hierarchy_id FROM taxon_concept_names tcn STRAIGHT_JOIN names n ON (tcn.name_id=n.id) STRAIGHT_JOIN taxon_concepts tc ON (tc.id = tcn.taxon_concept_id) LEFT JOIN taxon_concept_content tcc ON (tcn.taxon_concept_id=tcc.taxon_concept_id) LEFT JOIN hierarchy_entries he ON (tcn.source_hierarchy_entry_id=he.id) #{agent_clause} WHERE tcn.name_id IN (#{name_ids.join(',')}) AND (#{vetted_condition} #{agent_condition}) ORDER BY preferred DESC").all_hashes
    
    used_concept_ids = []
    sci_concepts = []
    com_concepts = []
    
    taxon_concept_ids.each do |result|
      if !used_concept_ids.include?(result['id'].to_i) || (result['hierarchy_id'].to_i == Hierarchy.default.id && result['preferred'].to_i == 1)
        
        # Remove existing concept representative if we have one from default hierarchy
        if result['hierarchy_id'].to_i == Hierarchy.default.id && result['preferred'].to_i == 1
          sci_concepts.delete_if { |concept| concept['id'] == result['id'] }
          com_concepts.delete_if { |concept| concept['id'] == result['id'] }
        end
        
        if result['is_vern'].to_i == 0
          sci_concepts << result
        else
          com_concepts << result
        end
        
        used_concept_ids << result['id'].to_i
      end
    end

    if taxon_concept_ids.length == 0
      errors ||= []
      errors << "There were no matches for the search term #{search_string}"
    end
    
    return {:common     => com_concepts,
            :scientific => sci_concepts,
            :errors     => errors}

  end
  
  def iucn_conservation_status
    return iucn.description
  end

  def iucn_conservation_status_url
    return iucn.respond_to?(:agent_url) ? iucn.agent_url : iucn.source_url
  end

  # TODO - find refs to these and make them grab a hierarchy...
  def current_node(hierarchy_id = nil)
    return entry(hierarchy_id)
  end
  def ancestry(hierarchy_id = nil)
    return entry(hierarchy_id).ancestors
  end

  def classification_attribution
    return entry.classification_attribution rescue ""
  end

  # pull list of categories for given taxa id
  def table_of_contents(options = {})
    #options = options.merge(:agent_id => @current_agent.id) unless @current_agent.nil?
    return @table_of_contents ||= TocItem.toc_for(id, :agent => @current_agent, :user => @current_user, :agent_logged_in => options[:agent_logged_in])
  end

  # pull content type by given category for taxa id 
  def content_by_category(category_id, options = {})
    toc_item = TocItem.find(category_id)
    sub_name = toc_item.label.gsub(/\W/, '_').downcase
    return self.send(sub_name) if self.private_methods.include?(sub_name)
    return get_default_content(category_id, options)
  end

  # This used to be singleton, but now we're changing the views (based on permissions) a lot, so I removed it.
  def images(options = {})
    images = DataObject.for_taxon(self, :image, :user => @current_user, :agent => @current_agent)
    @length_of_images = images.length # Caching this because the call to #images is expensive and we don't want to do it twice.
    return images
  end

  # title and sub-title depend on expertise level of the user that is passed in (default to novice if none specified)
  def title
    return @title unless @title.nil?
    title = quick_scientific_name(:italicized)
    @title = title.empty? ? name(:scientific) : title
  end

  def subtitle
    return @subtitle unless @subtitle.nil?
    subtitle = quick_common_name()
    subtitle = quick_scientific_name(:canonical) if subtitle.empty?
    subtitle = "<i>#{subtitle}</i>" unless subtitle.empty? or subtitle =~ /<i>/
    @subtitle = subtitle.empty? ? name() : subtitle
  end

  def iucn
    # Notice that we use find_by, not find_all_by.  We require that only one match (or no match) is found.
    my_iucn = DataObject.find_by_sql([<<EOIUCNSQL, id])[0]

    SELECT distinct do.*
      FROM taxon_concept_names tcn
        JOIN taxa t ON (tcn.name_id=t.name_id)
        JOIN harvest_events_taxa het ON (t.id=het.taxon_id)
        JOIN harvest_events he ON (het.harvest_event_id=he.id)
        JOIN data_objects_taxa dot ON (t.id=dot.taxon_id)
        JOIN data_objects do ON (dot.data_object_id=do.id)
      WHERE tcn.taxon_concept_id = ?
        AND he.resource_id = 3 
      LIMIT 1 # TaxonConcept.iucn

EOIUCNSQL
    temp_iucn = my_iucn.nil? ? DataObject.new(:source_url => 'http://www.iucnredlist.org/', :description => 'NOT EVALUATED') : my_iucn
    temp_iucn.instance_eval { def agent_url; return Agent.iucn.homepage; end }
    return temp_iucn
  end

  def smart_thumb
    return images.blank? ? nil : images[0].smart_thumb
  end

  def smart_medium_thumb
    return images.blank? ? nil : images[0].smart_medium_thumb
  end

  def smart_image
    return images.blank? ? nil : images[0].smart_image
  end

  # comment on this
  def comment user, body
    comment = comments.create :user => user, :body => body
    user.comments.reload # be friendly - update the user's comments automatically
    comment
  end
  
  def content_level
    taxon_concept_content.content_level
  end
  
  def self.direct_ancestors(tc)
    return [] if tc.nil?
    he_all = []
    tc.hierarchy_entries.each do |he|
      he_all << he
      parent = he.parent
      until parent.nil?
        he_all << parent
        parent = parent.parent
      end
    end
    he_all
  end

  def is_curatable_by? user
    he_all = TaxonConcept.direct_ancestors(self)
    # hierarchy_entries_with_parents_above_clade = hierarchy_entries_with_parents
    # hierarchy_entries_with_parents_above_clade
    permitted = he_all.find {|entry| user.curator_hierarchy_entry_id == entry.id }
    if permitted then true else false end
  end

  def self.exemplars
    # TODO - this is now taxon-concept centric, so IDs will have to change.
    if @exemplars.nil?
      list = [910093, 1009706, 912371, 976559, 597748, 1061748, 373667, 482935, 392557, 484592, 581125, 467045, 593213, 209984, 795869, 1049164, 604595, 983558, 253397, 740699, 1044544, 802455, 1194666, 2485151]
    end
    
    @@exemplars ||= TaxonConcept.find(:all, :conditions => ['id IN (?)', list])

  end

  def self.search(search_string, options = {})
    # TODO - we have qualifier, scope, and search_lang diabled for now, so I am ignoring them entirely.
    options[:qualifier]       ||= 'contains'
    options[:scope]           ||= 'all'
    options[:search_language] ||= 'all'

    # TODO - insert into search terms, popular searches, and the like.

    # TODO - I'm not sure this is really what we want to be doing, here: I simply reproduced Patrick's code (for the most part).
    search_terms = search_string.gsub(/\s+/, ' ').strip.split(/[ -&:\\'?;]+| and /)

    sci_concepts  = []
    com_concepts  = []
    errors       = nil
    num_matches  = {}

    search_terms.each do |orig_term|
      term = orig_term.gsub(/\*/, 'EOL_WILDCARD').gsub(/[\W\-]/, '').gsub('EOL_WILDCARD', '%')
      if term.gsub('%', '').length < 3
        errors ||= []
        errors << "All search terms must contain at least three characters. '#{orig_term}' is too short."
      end
      # I was going to make everything wildcarded, but....  term = "%#{term}%".gsub('%+', '%')
      search_type = term.match(/%/) ? 'LIKE' : '='

      # TODO - this will only search names (not authors or years), thanks to the hard-coded "1" below.
#       concepts = TaxonConcept.find_by_sql([<<EO_FIND_NAMES, term])
#   SELECT DISTINCT tc.id, tcn.vern vern
#     FROM taxon_concepts tc
#       JOIN taxon_concept_names tcn ON (tcn.taxon_concept_id = tc.id)
#       JOIN normalized_links nl ON (nl.name_id = tcn.name_id)
#       JOIN normalized_names nn ON (nn.id = nl.normalized_name_id)
#     WHERE nn.name_part #{search_type} ?
#       AND nl.normalized_qualifier_id = 1 # TaxonConcept.search
# EO_FIND_NAMES

      concepts = TaxonConcept.find_by_sql([<<EO_FIND_NAMES, term])
  SELECT DISTINCT tcn.taxon_concept_id id, tcn.vern vern
  FROM normalized_names nn
  STRAIGHT_JOIN normalized_links nl ON (nn.id=nl.normalized_name_id)
  STRAIGHT_JOIN taxon_concept_names tcn ON (nl.name_id=tcn.name_id)
  WHERE nn.name_part #{search_type} ?
  AND nl.normalized_qualifier_id = 1 # TaxonConcept.search
EO_FIND_NAMES

      # NOTE: For whatever reason, Rails makes TINYINTs into strings.  Thus the to_i.
      sci_concepts += concepts.find_all {|concept| concept.vern.to_i == 0 }
      com_concepts += concepts.find_all {|concept| concept.vern.to_i == 1 }
      if concepts.length == 0
        errors ||= []
        errors << "There were no matches for the search term #{orig_term}"
      end

    end

    return {:common     => com_concepts.compact.sort,
            :scientific => sci_concepts.compact.sort,
            :errors     => errors}

  end

  # This could use name... but I only need it for searches, and ID is all that matters, there.
  def <=>(other)
    return id <=> other.id
  end

  def visible_comments(user = @current_user)
    return comments if (not user.nil?) and user.is_moderator?
    comments.find_all {|comment| comment.visible? }
  end

#####################
private

# =============== The following are methods specific to content_by_category

  # These should never be called; they're containers, not a leaf nodes:
  # references_and_more_information
  # evolution_and_systematics

  def common_names
    # NOTES: we had a notion of "unspecified" language.  Results were sorted.
    result = {
        :content_type  => 'common names',
        :category_name => 'Common Names',
        :items         => Name.find_by_sql([
                            'SELECT names.string, l.iso_639_1 language_label, l.label, l.name
                               FROM taxon_concept_names tcn JOIN names ON (tcn.name_id = names.id)
                                 LEFT JOIN languages l ON (tcn.language_id = l.id)
                               WHERE tcn.taxon_concept_id = ? AND vern = 1
                               ORDER BY language_label, string', id])
      }
    return result
  end

  def specialist_projects
    # I did not include these outlinks as data object in the traditional sense. For now, you'll need to go through the
    # collections and mappings tables to figure out which links pertain to the taxon (mappings has the name_id field). I
    # had some thoughts about including these in the taxa / data_object route, but I don't have plans to make this change
    # any time soon.
    # 
    # I had the table hierarchies_content which was supposed to let us know roughly what we had for each hierarchies_entry
    # (text, images, maps...). But, maybe it makes sense to cache the table of contents / taxon relationships as well as
    # media. Another de-normalized table. It may seem sloppy, but I'm sure we'll have to use de-normalized tables a lot in
    # this project.

#     mappings = Mapping.find_by_sql([<<EO_MAPPING_SQL, id, @current_user.vetted])
#       
#       SELECT DISTINCT m.*, a.full_name agent_full_name, c.*
#         FROM taxon_concept_names tcn
#           LEFT JOIN mappings m USING (name_id)
#           LEFT JOIN collections c ON (m.collection_id = c.id)
#           LEFT JOIN agents a ON (c.agent_id = a.id)
#         WHERE tcn.taxon_concept_id = ?
#           AND (c.vetted = 1 OR c.vetted = ?) # Specialist Projects / Mappings
# 
# EO_MAPPING_SQL
# 
#     results = []
#     mappings.each do |mapping|
#       collection_url = mapping.collection.uri.gsub!(/FOREIGNKEY/, mapping.foreign_key)
#       results << {
#         :agent_name       => mapping.agent_full_name || '[unspecified]',
#         :collection_title => mapping.collection.title,
#         :collection_link  => mapping.collection.link,
#         :url              => collection_url,
#         :icon             => mapping.collection.logo_url # FIX THIS LATER TODO
#       }
#     end
    
    mappings = SpeciesSchemaModel.connection.execute("SELECT DISTINCT m.id mapping_id, m.foreign_key foreign_key, a.full_name agent_name, c.title collection_title, c.link collection_link, c.logo_url icon, c.uri collection_uri FROM taxon_concept_names tcn JOIN mappings m ON (tcn.name_id=m.name_id) JOIN collections c ON (m.collection_id=c.id) JOIN agents a ON (c.agent_id=a.id) WHERE tcn.taxon_concept_id = #{id} AND (c.vetted=1 OR c.vetted=#{@current_user.vetted}) GROUP BY c.id").all_hashes
    mappings.each do |mapping|
      mapping["url"] = mapping["collection_uri"].gsub!(/FOREIGNKEY/, mapping["foreign_key"])
    end
    
    sorted_mappings = mappings.sort_by { |mapping| mapping["agent_name"] }
    
    return {
          :content_type => 'ubio_links',
          :projects => sorted_mappings
        }

  end

  def biodiversity_heritage_library
    # items = ItemPage.find_by_sql([
    #                         'SELECT pt.title title, pt.url title_url, pt.details details, ip.*
    #                            FROM taxon_concept_names tcn 
    #                              JOIN page_names pn USING (name_id) 
    #                              JOIN item_pages ip ON (pn.item_page_id = ip.id)
    #                              JOIN title_items ti ON (ip.title_item_id = ti.id)
    #                              JOIN publication_titles pt ON (ti.publication_title_id = pt.id)
    #                            WHERE tcn.taxon_concept_id = ?
    #                             LIMIT 0,500 # TaxonConcept#bhl', id])  # TODO - sorting is wrong
    
    items = SpeciesSchemaModel.connection.execute("SELECT DISTINCT ti.id item_id, pt.title publication_title, pt.url publication_url, pt.details publication_details, ip.year item_year, ip.volume item_volume, ip.issue item_issue, ip.prefix item_prefix, ip.number item_number, ip.url item_url FROM taxon_concept_names tcn JOIN page_names pn ON (tcn.name_id=pn.name_id) JOIN item_pages ip ON (pn.item_page_id=ip.id) JOIN title_items ti ON (ip.title_item_id=ti.id) JOIN publication_titles pt ON (ti.publication_title_id=pt.id) WHERE tcn.taxon_concept_id = #{id} LIMIT 0,1000").all_hashes
    
    sorted_items = items.sort_by { |item| [item["publication_title"], item["item_year"], item["item_volume"], item["item_issue"], item["item_number"].to_i] }
    
    return {
          :content_type  => 'bhl',
          :category_name => 'Biodiversity Heritage Library',
          :items         => sorted_items
        }
  end

  def catalogue_of_life_synonyms
    return {
        :content_type  => 'synonyms',
        :category_name => 'Catalogue of Life Synonyms',
        :synonyms      => Synonym.by_taxon(col_entry.id).reject { |syn|
                            syn.synonym_relation.label == 'common name' }.sort_by {|syn| syn.name.string }
      }
  end

  def get_default_content(category_id, options)
    options.merge(:agent_id => @current_agent.id) unless @current_agent.nil?
    result = {
      :content_type  => 'text',
      :category_name => TocItem.find(category_id).label,
      :data_objects  => DataObject.for_taxon(self, :text, :toc_id => category_id, :agent => @current_agent, :user => @current_user)
    }
    # TODO = this should not be hard-coded! IDEA = use partials.  Then we have variables and they can be dynamically changed.
    # NOTE: I tried to dynamically alter data_objects directly, below, but they didn't
    # "stick".  Thus, I override the array:
    override_data_objects = []
    puts "*" * 120
    result[:data_objects].each do |data_object|
      if data_object.sources.detect { |src| src.full_name == 'FishBase' }
        # TODO - We need a better way to choose which Agent to look at.  : \
        # TODO - We need a better way to choose which Collection to look at.  : \
        # TODO - We need a better way to choose which Mapping to look at.  : \
        foreign_key      = data_object.agents[0].collections[0].mappings[0].foreign_key
        (genus, species) = entry.name(:canonical).split()
        data_object.fake_author(
          :full_name => 'See FishBase for additional references',
          :homepage  => "http://www.fishbase.org/References/SummaryRefList.cfm?ID=#{foreign_key}&GenusName=#{genus}&SpeciesName=#{species}",
          :logo_url  => '')
      end
      override_data_objects << data_object
    end
    result[:data_objects] = override_data_objects
    return result
  end

# =============== END of content_by_category methods

end
# == Schema Info
# Schema version: 20081020144900
#
# Table name: taxon_concepts
#
#  id             :integer(4)      not null, primary key
#  supercedure_id :integer(4)      not null


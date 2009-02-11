/*
 * Misc Javascript variables and functions.
 *
 * This could all likely use some cleanup.  Some of this stuff could be:
 *
 *  - turned into event-based unobtrusive javascript
 *  - simply named / namespaced a bit better
 *  - the html generated from javascript strings could
 *    likely be improved or moved to the server-side
 *
 */ 

// DEPRECATED
var image_attribution_panel_open = false;
function toggle_image_attribution()         { EOL.log("obsolete method called: toggle_image_attribution"); }
function hide_image_attribution()           { EOL.log("obsolete method called: hide_image_attribution"); }
function show_image_attribution()           { EOL.log("obsolete method called: show_image_attribution"); }
function create_attribution_table_header()  { EOL.log("obsolete method called: create_attribution_table_header"); }
function create_attribution_table_row()     { EOL.log("obsolete method called: create_attribution_table_row"); }
function create_attribution_table_footer()  { EOL.log("obsolete method called: create_attribution_table_footer"); }

function textCounter(field,cntfield,maxlimit) {
	if (field.value.length > maxlimit) // if too long...trim it!
		field.value = field.value.substring(0, maxlimit);
	// otherwise, update 'characters left' counter
	else
		cntfield.innerHTML = maxlimit - field.value.length + ' remaining';
}

// update the content area
function eol_update_content_area(taxon_id,category_id) {
    // i feel like this could be a lot simpler ... 
    new Ajax.Request('/taxa/content/', {
             parameters: { id: taxon_id, category_id: category_id },         
            onComplete:function(request){hideAjaxIndicator(true);updateReferences();},
            onSuccess:function(request){hideAjaxIndicator(true);updateReferences();},
            onError: function(request){hideAjaxIndicator(true);},
            onLoading:function(request){showAjaxIndicator(true);},
            asynchronous:true,
            evalScripts:true});
    $A(document.getElementsByClassName('active', $('toc'))).each(function(e) { e.className = ''; });
}

// show the pop-up in the div 
function eol_show_pop_up(div_name,partial_name,taxon_name) {
				if (partial_name==null) partial_name=div_name;
				if (taxon_name==null) taxon_name='';
        new Ajax.Updater(
        div_name,
        '/taxa/show_popup',
          {
            asynchronous:true, 
            evalScripts:true, 
            method:'post', 
            onComplete:function(request){hideAjaxIndicator();EOL.Effect.toggle_with_effect(div_name);},
            onLoading:function(request){showAjaxIndicator();},
            parameters:{name: partial_name,taxon_name: taxon_name}
          }
    );
    
}

// Updates the main image and calls eol_update_credit()
function eol_update_image(large_image_url, params) {
  $('main-image').src = large_image_url;
  $('main-image').alt=params.nameString;
  $('main-image').title=params.nameString;
    
  // update the hrefs for the comment, curation, etc popups
  if($$('div#large-image-trust-button a')[0]) {
    if (!params.curated) {
      $$('div#large-image-trust-button a')[0].href="/data_objects/"+params.data_object_id+"/curate?_method=put&curator_activity_id=3";
      $$('div#large-image-untrust-button a')[0].href="/data_objects/"+params.data_object_id+"/curate?_method=put&curator_activity_id=7";
      $$('div#large-image-untrust-button a')[0].writeAttribute('data-data_object_id', params.data_object_id);
      $$('div#large-image-trust-button a')[0].writeAttribute('data-data_object_id', params.data_object_id);
      
      $('large-image-trust-button').appear();
      $('large-image-untrust-button').appear();
    } else {
      $('large-image-trust-button').disappear();
      $('large-image-untrust-button').disappear();
    }
  }
  if ($('large-image-comment-button-popup-link'))     $('large-image-comment-button-popup-link').href = "/data_objects/" + params.data_object_id + "/comments";
  if ($('large-image-attribution-button-popup-link')) $('large-image-attribution-button-popup-link').href = "/data_objects/" + params.data_object_id + "/attribution"; 
  if ($('large-image-tagging-button-popup-link'))     $('large-image-tagging-button-popup-link').href = "/data_objects/" + params.data_object_id + "/tags"; 
  if ($('large-image-curator-button-popup-link'))     $('large-image-curator-button-popup-link').href = "/data_objects/" + params.data_object_id + "/curation"; 

  eol_update_credit(params);

  // make a logging call to let the server know that we've viewed this image
  eol_log_data_objects_for_taxon_concept( params.taxonID, params.data_object_id );
    
  return false;
}

// Updates the image credit box
//
// TODO - this should be fetched from the server-side ... way too much HTML generation in the javascript
//
// ... this updates abunchof stuff and is pretty disorganized  :(
//
function eol_update_credit(params){

    // ! FIELD NOTES ! <start> NOTE: this should really be moved into a partial on the server side!
    field_notes_area = '';

    if (params.taxaIDs.length > 0 ) {
      var current_page_name_or_id = window.location.toString().sub(/.*\//,'');
      var taxa_thats_not_the_current_page = 0;    
      // loop thru and find a taxa that's NOT the current page's taxa
      while (params.taxaIDs[taxa_thats_not_the_current_page] != null && current_page_name_or_id == params.taxaIDs[taxa_thats_not_the_current_page].toString() ) {
        taxa_thats_not_the_current_page++;
      }
      // if it exists, show it ...
      if ( params.taxaIDs[taxa_thats_not_the_current_page] != null ) {
        field_notes_area += 'Image of <a href="/pages/' + params.taxaIDs[taxa_thats_not_the_current_page] + '">' + params.taxaNames[taxa_thats_not_the_current_page] + '</a><br />';
      }
    }
    if (params.license_text != '') {
        field_notes_area += 'COPYRIGHT: ' + params.license_text + '<a href="' + params.license_link + '" class="external_link"> <img src="'  + params.license_logo + '"></a><br />';
    }
    if (params.data_supplier != '') {
      if (params.data_supplier_url != '') {
		field_notes_area += 'SUPPLIER: <a href="'+params.data_supplier_url+'" class="external_link">' + params.data_supplier + ' <img alt="external link" src="/images/external_link.png"></a> ' + params.data_supplier_icon  + '<br />';
      } else { 
        field_notes_area += 'SUPPLIER: ' + params.data_supplier + '<br />';
      }
    }
    if (params.authors_linked != '') {
        field_notes_area += 'AUTHOR: ' + params.authors_linked + '<br />';
    }
    if (params.sources != '' && params.info_url != '' && params.info_url != null) {
 		field_notes_area += 'SOURCE: <a href="'+params.info_url+'" class="external_link">' +  params.sources + ' <img alt="external link" src="/images/external_link.png"></a><br />';
    }
    else if (params.sources_linked != '') {
        field_notes_area += 'SOURCE:' + params.sources_linked + '<br />';
    }   
    if (params.sources_icons_linked != '') {
        field_notes_area += params.sources_icons_linked + '<br />';
    }
    field_notes_area += '<br /><br />';
    field_notes_area += params.field_notes ? params.field_notes : "";				
    
    var left_buttons = $('large-image-button-group').childElements();
    if (params.published){
      if (left_buttons.size() > 1) {
        left_buttons.first().remove();
      }
    } else {
      if (left_buttons.size() == 1) {
        var buttons = $('large-image-button-group').innerHTML;
        $('large-image-button-group').innerHTML="<li style=\"position:relative;top:3px;background-image:url('/images/icons/preview.png');background-repeat:no-repeat\" title=\"Unpublished\" />\n" +buttons;
      }
    }

    $('large-image-attribution-button').removeClassName('unknown');
    $('large-image-attribution-button').removeClassName('untrusted');
    $('mc-notes').removeClassName('unknown-background-text');
    $('mc-notes').removeClassName('untrusted-background-text');
    $('main-image-bg').removeClassName('unknown-background-image');
    $('main-image-bg').removeClassName('untrusted-background-image');

    if (params.vetted_id == EOL.Curation.UNKNOWN_ID) {
      $('mc-notes').addClassName('unknown-background-text');
      $('main-image-bg').addClassName('unknown-background-image');
      $('large-image-attribution-button').addClassName('unknown');
      field_notes_area += '<br /><br /><strong>Note:</strong> The image from this source has not been reviewed.';
    } else if (params.vetted_id == EOL.Curation.UNTRUSTED_ID) {
      $('mc-notes').addClassName('untrusted-background-text');
      $('main-image-bg').addClassName('untrusted-background-image');
      $('large-image-attribution-button').addClassName('untrusted');
      field_notes_area += '<br /><br /><strong>Note:</strong> The image from this source is not trusted.';
    }
    
    $('field-notes').innerHTML = field_notes_area; // this is the 'gray box'
    // ! FIELD NOTES ! </end>

    EOL.reload_behaviors();
}

// Updates the main image and calls eol_update_credit()
function eol_update_video(params) {
    $$('div#media-videos div.attribution_link')[0].show();
    for(var i in EOL.popups) {
      EOL.popups[i].destroy();
    }
    $('video_attributions').href = "/data_objects/" + params.data_object_id + "/attribution"; 

    new Ajax.Request('/taxa/show_video/', {
             parameters: { video_type: params.video_type, video_url: params.video_url},
            onComplete:function(request){hideAjaxIndicator();},
            onLoading:function(request){showAjaxIndicator();},
            asynchronous:true,
            evalScripts:true});
    
    license_info='';
    if (params.license_logo != '') {
        license_info += '<a href="' + params.license_link + '" target="_blank"><img src="' + params.license_logo + '" border="0"></a>&nbsp;&nbsp;';
    }
    if (params.license_text != '') {
        license_info += params.license_text;
    }    
    
    video_notes_area = '';
    video_notes_area += params.title +'<br /><br />';
    if (params.author != '') {video_notes_area += 'AUTHOR: ' + params.author + '<br /><br />';}
    if (params.collection != '') {video_notes_area += 'SOURCE: ' + params.collection + '<br /><br />';}
    if (license_info != '') {video_notes_area += license_info + '<br /><br />';}
          video_notes_area += params.field_notes ? params.field_notes : "";
                
    $('video-notes').innerHTML = video_notes_area;

    // make a logging call to let the server know that we've viewed this image
    eol_log_data_objects_for_taxon_concept( params.taxon_concept_id, params.data_object_id );
		    
    return false;
}

// Setup the EOL vetted slider
function eol_slider(vetted, taxon_id) {
    if (vetted == 'true') {
        $('slider').setStyle({ backgroundPosition: '-165px center' });
    } else {
        $('slider').setStyle({ backgroundPosition: '-50px center' });
    }
    new Control.Slider('handle','slider',{
        range:$R(0,100),
        sliderValue: (vetted == 'true') ? 20 : 75,
        onSlide:function(v){
            var x = v / 100 * 205;
            x = (-205 + Number(x.toFixed()));
            $('slider').setStyle({
                backgroundPosition: x+'px center'
            });
        },
        onChange:function(v){
            var base_url = "/pages/" + taxon_id + "?"
            var params = new Hash({vetted: 'true'});
            if ($('current_content').value != "") { params.set('category_id', $('current_content').value); }

            if(v <= 45) {
                params.set('vetted', 'true');
            } else {
                params.set('vetted', 'false');
            }

            window.location.href = base_url + params.toQueryString();
        }
    });
}

function displayNode(id) {
	displayNode(id, false)
}

// call remote function to show the selected node in the text-based navigational tree view
function displayNode(id, for_selection) {
	url = '/navigation/show_tree_view'
	if(for_selection) {
		url = '/navigation/show_tree_view_for_selection'
	}
        new Ajax.Updater(
        'browser-text', url,
          {
              asynchronous:true, 
            evalScripts:true, 
            method:'post', 
            onComplete:function(request){hideAjaxIndicator();},
            onLoading:function(request){showAjaxIndicator();},
            parameters:'id='+id
          }
    );
}

function eol_change_to_flash_browser()
{
    if ($('classification-attribution-button_popup') != null) {EOL.Effect.disappear('classification-attribution-button_popup');}           
    EOL.Effect.disappear('browser-text');
    EOL.Effect.appear('browser-flash');                
    update_default_taxonomic_browser('flash');    
}

function eol_change_to_text_browser()
{
    if ($('classification-attribution-button_popup') != null) {EOL.Effect.disappear('classification-attribution-button_popup');}           
    EOL.Effect.disappear('browser-flash');
    EOL.Effect.appear('browser-text');
    update_default_taxonomic_browser('text');
}

function update_default_taxonomic_browser(default_browser)
{
        new Ajax.Request(
        '/navigation/set_default_taxonomic_browser',
          {
            asynchronous:true, 
            evalScripts:true, 
            method:'get',     
            parameters:'browser='+default_browser
          }
    );
}

function toggle_children() {
    Element.toggle('taxonomic-children');
    if ($('toggle_children_link').innerHTML=='-') {
        $('toggle_children_link').innerHTML='+'
    }
    else
    {
        $('toggle_children_link').innerHTML='-'        
    }
}

// DEPRECATED!  let's use EOL.Ajax.start() / .finish()
function showAjaxIndicator(on_content_area) {
    on_content_area = on_content_area || false
    if (on_content_area)
    {
        Element.show('center-page-content-loading');
    }
    Element.show('ajax-indicator');
}
function hideAjaxIndicator(on_content_area) {
    on_content_area = on_content_area || false    
    if (on_content_area)
    {
        Element.hide('center-page-content-loading');
    }    
    Element.hide('ajax-indicator');        
}

function eol_log_data_objects_for_taxon_concept( taxon_concept_id, data_object_ids ) {
  // make a logging call to let the server know we have seen an object
  new Ajax.Request('/taxa/view_object/', {
		method: 'post',
    parameters: { id: data_object_ids, taxon_concept_id: taxon_concept_id },
    asynchronous: true 
  });	
}

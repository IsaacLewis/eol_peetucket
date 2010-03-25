/*
 * EOL Javascript : Common functions, Global variables, etc
 *
 * This defines the EOL namespace which can be used for various common functions that get used throughout the application.
 *
 * This allows for better / easier convention following.  For example, instead of using Script.aculo.us effects, directly,
 * you can [define and] use an EOL effects so that every time we want to show or hide something, we use the same effect,
 * with the same options passed, etc.  Making everything nice and conventional  :)
 *
 * Here are some conventions we can use for this:
 *  - Classes and Namespaces should be PascalCase
 *  - Functions and Variables should be camelCase
 *
 * For "classes" and whatnot, we should use Prototype.
 *
 * When a function accepts an 'element' as an argument, assume that it could be the 'id' or an element or an actual DOM element
 *
 */
var EOL = {};

/*
 * Miscellaneous Helper Functions and whatnot
 *
 */

// log something to the console (if a console is available, else do nothing)
EOL.log_enabled = true;
EOL.log = function( msg ) {
  if ( EOL.log_enabled ) {
    try {
      console.log(msg);
    } catch (e) {
      EOL.log_enabled = false;
    }
  }
};

// what is this supposed to do?  where is it used?  (i can't find it used anywhere)
EOL.defer_click = function(e) {
  Event.observe(window, 'load', function() {e.onclick();});
  return(false);
};

// reload all UJS behaviors
EOL.reload_behaviors = function() {
  Event.addBehavior.reload();
};

// get the current app path # there may be a prototype built-in function for easily doing this, i just gsub out everything before the /path
EOL.current_path = function() {
  return window.location.toString().gsub(/https?:\/\//,'').gsub(/^([^/])/,'');
};

// Some behaviors to perform when Ajax new calls start or finish (when all have finished)
//
// these functions handle their own # of active ajax requests because we have requests coming 
// from Prototype *and* from jQuery ... otherwise, we're let the frameworks deal with that
//
EOL.Ajax = {
  start: function() {
    EOL.Ajax.activeAjaxCalls++;
    if (EOL.Ajax.activeAjaxCalls == 1) {
      if ($('ajax-indicator')) {$('ajax-indicator').show();}
    }
  },
  finish: function() {
    EOL.Ajax.activeAjaxCalls--;
    if (EOL.Ajax.activeAjaxCalls == 0) {
      if ($('ajax-indicator')) {$('ajax-indicator').hide();}
    }
  }
};
EOL.Ajax.activeAjaxCalls = 0;

/*
 *  Common EOL Effects
 *
 *  show/hide are not effects - they should simply set the visibility of an object.  $('element').show() / .hide() are good conventional ways of doing this.
 *
 *  appear/disappear are effects.  they're how we conventionally introduce new content to a page (like a popup) or hide it.
 *  EOL.Effect.[dis]appear( element ) or element.[dis]appear() are good conventional ways of doing this.
 *
 *  similarly, toggle() toggles between whether an element is shown/hidden.  to toggle with effects, call toggle_with_effect() instead
 *
 */  
EOL.Effect = {};

EOL.Effect.appear = function(element, options) {
  options = options || { delay: 0.1, duration: 0.3 };
  Effect.Appear( element, options );
};

EOL.Effect.disappear = function(element, options) {
  options = options || { duration: 0.3 };
  Effect.Fade( element, options );
};

EOL.Effect.toggle_with_effect = function(element) {
  if ($(element).visible()) {
    EOL.Effect.disappear(element);
  } else {
    EOL.Effect.appear(element);
  }
};

// Notice that this does NOT interrupt the event.  If you add this to a click(), it may work.
EOL.addReturnTo = function(link) {
  if (link.href == null) { // Not a link, silly!
    return;
  } else if (link.href.match(/\?/) == null) { // There are no params in it yet
    link.href += "?"
  } else { // There are already params in this link
    link.href += "&"
  }
  link.href += "return_to=" + location.href.replace(/^http:\/\/[^\/]*/, '') // Removes protocol + host
}

/* 
 * Prototype Additions / Overrides
 *
 * Any of the Prototype default methods we want to override or any new methods we want to add
 *
 */ 
Element.addMethods({
  appear:    EOL.Effect.appear,
  disappear: EOL.Effect.disappear,
  toggle_with_effect: EOL.Effect.toggle_with_effect
});

EOL.load_taxon_comments_tab = function(extra_params) {
  new Ajax.Updater('taxaCommentsWrap', '/comments/',
                   {asynchronous:true, evalScripts:true, method:'get',
                    parameters: $H({ body_div_name: 'taxaCommentsWrap', taxon_concept_id: $('current_taxon_concept_id').value }).merge(extra_params),
                    onLoading:function() {
                      // onloading sometimes runs twice, and second time moves comment div down. 
                      // A bit hackish way to fix it is to run onloading function only when 
                      // taxaCommentsWrap is hidden
                      if ($('taxaCommentsWrap').style.display != 'none'){
                        EOL.Effect.appear('loading-comments');
                        $('taxaCommentsWrap').style.display = 'none';
                      }
                    },
                    onSuccess:function() {EOL.Effect.disappear('loading-comments');
                      EOL.Effect.appear('taxaCommentsWrap');}
                   });
};

EOL.validate_search_parameters = function(form,advanced_search) {
  if (form.q.value.trim() == "") {
    error_message='';
    $('search_message').update(error_message);
    if (advanced_search == true) {
      $('advanced_search_message').update(error_message);
    }
    $('q').focus();
    return false;
  } else {
    Element.hide('search_image');
    if (advanced_search == true) {
      $('advanced_search_message').update('Searching...');
    } else {
      $('search_message').update('Searching...');
    }
    if(!advanced_search) {
      EOL.Search.show_top_spinner();
    } else {
      Element.show('ajax-indicator');
    }
    return true;
  }
}

EOL.clear_search_field = function(form_field) {
  if (form_field.value != '') {
    form_field.value='';
  }
}

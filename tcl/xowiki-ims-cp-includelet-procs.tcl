

    #
    # sXorm Player's TreeRenderer
    #

    ::xowiki::TreeRenderer create ::xowiki::TreeRenderer=scorm_navigation \
        -superclass ::xowiki::TreeRenderer=list \
        -ad_doc {
            this is a specialized Tree Renderer for the categories tree:
             <ul>
             <li>includes a "target" property in the link (links to the sXorm player)
             <li>includes all pages in the package (not only root folder)
             </ul>
        }

   ::xowiki::TreeRenderer=scorm_navigation instproc render_item {{-highlight:boolean false} item} {
        $item instvar title prefix suffix href
        append entry \
            [::xowiki::Includelet html_encode $prefix] \
            "<a href='$href' target='sxorm-player'>" \
            [::xowiki::Includelet html_encode $title] \
            "</a>[::xowiki::Includelet html_encode $suffix]"
        if {$highlight} {
            return "<li class='liItem'><b>$entry</b></li>\n"
        } else {
            return "<li class='liItem'>$entry</li>\n"
        }
    }

  #  ::xowiki::TreeRenderer=scorm_navigation instproc render_node {{-open:boolean false} cat_content} {
  #      set cl [lindex [my info precedence] 0]
  #      set o_atts [lindex [$cl li_expanded_atts] [expr {[my expanded] ? 0 : 1}]]
  #      set h_atts [lindex [$cl highlight_atts] [expr {[my highlight] ? 0 : 1}]]
  #      set u_atts ""

  #      if {[my exists li_id]} {append o_atts " id='[my set li_id]'"}
  #      if {[my exists ul_id]} {append u_atts " id='[my set ul_id]'"}
  #      if {[my exists ul_class]} {append u_atts " class='[my set ul_class]'"}

  #      set label [::xowiki::Includelet html_encode [my label]]
  #      if {[my exists count]} {
  #          set entry "$label <a href='[my href]'>([my count])</a>"
  #      } else {
  #          if {[my href] ne ""} {
  #              set entry "<a href='[my href]'>$label</a>"
  #          } else {
  #              set entry [my label]
  #          }
  #      }
  #      if {$cat_content ne ""} {set content "\n<ul $u_atts>\n$cat_content</ul>"} else {set content ""}
  #      return "<li $o_atts><span $h_atts>[my prefix] $entry</span>$content"
  #  }


  #
  # sXorm Category Tree
  #
  # the only difference to the xowiki version is that we use the package_id to get the pages
  #


    Class ::xowiki::includelet::CategoryOrganization \
        -superclass ::xowiki::includelet::categories

    ::xowiki::includelet::CategoryOrganization instproc initialize {} {
        my get_parameters

        switch -- $style {
          "scorm_navigation"        {set s "scorm_navigation"; set list_mode 1; set renderer scorm_navigation}
          "scorm_organization_xml"  {set s "scorm_organization_xml"; set list_mode 1; set renderer scorm_organization_xml}
          "default"                 {set s "scorm_organization_xml"; set list_mode 1; set renderer scorm_organization_xml}
        }
        my set renderer $renderer
        my set style $s
        my set list_mode $list_mode

    }

   # ::xowiki::includelet::CategoryOrganization instproc render_list {{-full false} pages} {
   #     my get_parameters
   #     if {$open_page ne ""} {
   #         set allow_reorder ""
   #     } else {
   #         set allow_reorder [my page_reorder_check_allow -with_head_entries false $allow_reorder]
   #     }
   #     set tree [my build_tree -full $full -remove_levels $remove_levels \
   #             -book_mode $book_mode -open_page $open_page -expand_all $expand_all \
   #             $pages]
   #     my page_reorder_init_vars -allow_reorder $allow_reorder js last_level ID min_level
   #     return [$tree render -style [my set renderer] -context {min_level $min_level}]
   # }

    xowiki::includelet::CategoryOrganization ad_instproc render {} {
      We overwrite the standard render method, because we need to include all pages that belong
      to the package, not only those in the root folder
    } {
    my get_parameters

    set content ""
    set folder_id [$package_id folder_id]
    set open_item_id [expr {$open_page ne "" ?
                [::xo::db::CrClass lookup -name $open_page -parent_id $folder_id] : 0}]

    foreach {locale locale_clause} \
        [::xowiki::Includelet locale_clause -revisions r -items ci $package_id $locale] break

    set trees [::xowiki::Category get_mapped_trees -object_id $package_id -locale $locale \
                   -names $tree_name \
                   -output {tree_id tree_name}]

    #my msg "[llength $trees] == 0 && $tree_name"
    if {[llength $trees] == 0 && $tree_name ne ""} {
      # we have nothing left from mapped trees, maybe the tree_names are not mapped; 
      # try to get these
      foreach name $tree_name {
        #set tree_id [lindex [category_tree::get_id $tree_name $locale] 0]
        set tree_id [lindex [category_tree::get_id $tree_name] 0]
        if {$tree_id ne ""} {
          lappend trees [list $tree_id $name]
        }
      }
    }

    set edit_html [my category_tree_edit_button -object_id $package_id -allow_edit $allow_edit]
    if {[llength $trees] == 0} {
      return [my category_tree_missing -name $tree_name -edit_html $edit_html]
    }

    if {![my exists id]} {my set id [::xowiki::Includelet html_id [self]]}

    foreach tree $trees {
      foreach {tree_id my_tree_name ...} $tree {break}

      set edit_html [my category_tree_edit_button -object_id $package_id \
             -allow_edit $allow_edit -tree_id $tree_id]
      #append content "<div style='float:right;'>$edit_html</div>\n"

      #if {!$no_tree_name} {
      #  append content "<h3>$my_tree_name $edit_html</h3>"
      #} elseif {$edit_html ne ""} {
      #  append content "$edit_html<br>"
      #}
      set categories [list]
      set pos 0
      set cattree(0) [::xowiki::Tree new -volatile -orderby pos \
              -id [my id]-$my_tree_name -name $my_tree_name]

      set category_infos [::xowiki::Category get_category_infos \
                  -locale $locale -tree_id $tree_id]
      foreach category_info $category_infos {
        foreach {cid category_label deprecated_p level} $category_info {break}
        set c [::xowiki::TreeNode new -orderby pos  \
                   -level $level -label $category_label -pos [incr pos]]
        set cattree($level) $c
        set plevel [expr {$level -1}]
        $cattree($plevel) add $c
        set category($cid) $c
        lappend categories $cid
      }

      if {[llength $categories] == 0} {
        return $content
      }

      if {[info exists ordered_composite]} {
        set items [list]
        foreach c [$ordered_composite children] {lappend items [$c item_id]}

        # If we have no item, provide a dummy one to avoid sql error
        # later
        if {[llength $items]<1} {set items -4711}

        if {$count} {
          set sql "category_object_map c
             where c.object_id in ([join $items ,]) "
        } else {
          # TODO: the non-count-part for the ordered_composite is not
          # tested yet. Although "ordered compostite" can be used
          # only programmatically for now, the code below should be
          # tested. It would be as well possible to obtain titles and
          # names etc. from the ordered composite, resulting in a
          # faster SQL like above.
          set sql "category_object_map c, cr_items ci, cr_revisions r
            where c.object_id in ([join $items ,])
              and c.object_id = ci.item_id and 
              and r.revision_id = ci.live_revision 
           "
        }
      } else {
    #        set sql "category_object_map c, cr_items ci, cr_revisions r, xowiki_page p \
    #		where c.object_id = ci.item_id and ci.parent_id = $folder_id \
    #		and ci.content_type not in ('::xowiki::PageTemplate') \
    #		and c.category_id in ([join $categories ,]) \
    #		and r.revision_id = ci.live_revision \
    #		and p.page_id = r.revision_id \
    #                and ci.publish_status <> 'production'"


    ####################### CHANGED PART ####################################################################################
    #
        set sql "category_object_map c, cr_items ci, cr_revisions r, xowiki_page p, acs_objects o \
        where c.object_id = ci.item_id and o.object_id = ci.item_id and o.package_id = $package_id \
        and ci.content_type not in ('::xowiki::PageTemplate') \
        and c.category_id in ([join $categories ,]) \
        and r.revision_id = ci.live_revision \
        and p.page_id = r.revision_id \
                and ci.publish_status <> 'production'"
    #
    ####################### CHANGED PART ####################################################################################
      }

      if {$except_category_ids ne ""} {
        append sql \
            " and not exists (select * from category_object_map c2 \
        where ci.item_id = c2.object_id \
        and c2.category_id in ($except_category_ids))"
      }
      #ns_log notice "--c category_ids=$category_ids"
      if {$category_ids ne ""} {
        foreach cid [split $category_ids ,] {
          append sql " and exists (select * from category_object_map \
         where object_id = ci.item_id and category_id = $cid)"
        }
      }
      append sql $locale_clause
      
      if {$count} {
        db_foreach [my qn get_counts] \
            "select count(*) as nr,category_id from $sql group by category_id" {
              $category($category_id) set count $nr
              set s [expr {$summary ? "&summary=$summary" : ""}]
              $category($category_id) href [ad_conn url]?category_id=$category_id$s
              $category($category_id) open_tree
      }
        append content [$cattree(0) render -style [my set renderer]]
      } else {
        foreach {orderby direction} [split $order_items_by ,]  break     ;# e.g. "title,asc"
        set increasing [expr {$direction ne "desc"}]
    set order_column ", p.page_order" 

        db_foreach [my qn get_pages] \
            "select ci.item_id, ci.name, ci.parent_id, r.title, o.package_id, category_id $order_column from $sql" {
              if {$title eq ""} {set title $name}
              set itemobj [Object new]
              set prefix ""
              set suffix ""
              foreach var {name title prefix suffix page_order} {$itemobj set $var [set $var]}
              # BEGIN CHANGE #######################################################################################################
              $itemobj set href [::$package_id pretty_link -parent_id $parent_id $name]
              $itemobj set page_id $item_id
              # END CHANGE #########################################################################################################
              $cattree(0) add_item \
                  -category $category($category_id) \
                  -itemobj $itemobj \
                  -orderby $orderby \
                  -increasing $increasing \
                  -open_item [expr {$item_id == $open_item_id}]
            }
        append content [$cattree(0) render -style [my set renderer]]
      }
    }
    # BEGIN CHANGE #######################################################################################################
    if {[my set renderer] eq "scorm_organization_xml"} {
        set content "<organizations>$content</organizations>"
    }
    # END CHANGE #########################################################################################################

    return $content
}



    ##############################
    #
    # Used for exporting the Book Org as IMS CP
    #
    ##############################

    Class ::xowiki::includelet::BookOrganization -superclass ::xowiki::includelet::toc

    ::xowiki::includelet::BookOrganization instproc initialize {} {

        my get_parameters

        switch -- $style {
          "scorm_navigation"        {set s "scorm_navigation"; set list_mode 1; set renderer scorm_navigation}
          "scorm_organization_xml"  {set s "scorm_organization_xml"; set list_mode 1; set renderer scorm_organization_xml}
          "default"                 {set s "scorm_organization_xml"; set list_mode 1; set renderer scorm_organization_xml}
        }
        my set renderer $renderer
        my set style $s
        my set list_mode $list_mode

    }

    ::xowiki::includelet::BookOrganization ad_instproc render_list {{-full true} pages} {
        changed the default of full to true (could be done elsewhere?)
      } {
        my get_parameters
        # TODO clean up this method
        if {$open_page ne ""} {
          set allow_reorder ""
        } else {
          set allow_reorder [my page_reorder_check_allow -with_head_entries false $allow_reorder]
        }
        set tree [my build_tree -full $full -remove_levels $remove_levels \
              -book_mode $book_mode -open_page $open_page -expand_all $expand_all \
              $pages]
        my page_reorder_init_vars -allow_reorder $allow_reorder js last_level ID min_level
        return [$tree render -style [my set style] -context {min_level $min_level}]
    }

    #
    # sXorm Player's TreeRenderer for exporting the org as scorm-xml
    #

    ::xowiki::TreeRenderer create ::xowiki::TreeRenderer=scorm_organization_xml \
        -superclass ::xowiki::TreeRenderer=list

    ::xowiki::TreeRenderer=scorm_organization_xml proc include_head_entries {args} { }

    ::xowiki::TreeRenderer=scorm_organization_xml proc render {tree} {
        set title [expr {[$tree name] ne "" ? [$tree name] : [$tree id]}]
        set orgid [::xoutil::XMLClass get_valid_id [$tree id]]
        return "<organization id='$orgid'>\n<title>$title</title>\n[next]\n</organization>"
    }

    ::xowiki::TreeRenderer=scorm_organization_xml instproc render_item {{-highlight:boolean false} item} {
        return ""
      #   $item instvar title prefix suffix href
      #   ds_comment "[my serialize]"

      #   set label [::xowiki::Includelet html_encode [my label]]
      #   set itemid [::xoutil::XMLClass get_valid_id [self]]

      #   if {[my exists object]} {
      #       set refid_att "identifierref='[::xoutil::XMLClass get_valid_id [[my object] set page_id]]'"
      #   } elseif {[my isobject [self]::items]} {
      #       # Note, that we assume to have only one item attached
      #       set page_id [[lindex [[self]::items children] 0] set page_id]
      #       set refid_att "identifierref='[::xoutil::XMLClass get_valid_id $page_id]'"
      #   } else {
      #       set refid_att ""

      #   }
      #   set entry "<item identifier='$itemid' $refid_att>\n"

      #   append entry \
      #       "\t<title>" \
      #       [::xowiki::Includelet html_encode $prefix]\
      #       [::xowiki::Includelet html_encode $label]\
      #       [::xowiki::Includelet html_encode $suffix]\
      #       "</title>\n"

      #       return " "
      #   return "$entry<item>"
    }
    ::xowiki::TreeRenderer=scorm_organization_xml instproc render_node {{-open:boolean true} cat_content} {
        set cl [lindex [my info precedence] 0]
        set o_atts [lindex [$cl li_expanded_atts] [expr {[my expanded] ? 0 : 1}]]
        set h_atts [lindex [$cl highlight_atts] [expr {[my highlight] ? 0 : 1}]]
        set u_atts ""

        if {[my exists li_id]} {append o_atts " id='[my set li_id]'"}
        if {[my exists ul_id]} {append u_atts " id='[my set ul_id]'"}
        if {[my exists ul_class]} {append u_atts " class='[my set ul_class]'"}

        set label [::xowiki::Includelet html_encode [my label]]
        set itemid [::xoutil::XMLClass get_valid_id [self]]
            
        

        if {[my exists object]} {
            set refid_att "identifierref='[::xoutil::XMLClass get_valid_id [[my object] set page_id]]'"
        } elseif {[my isobject [self]::items]} {
            # Note, that we assume to have only one item attached
            set page_id [[lindex [[self]::items children] 0] set page_id]
            set refid_att "identifierref='[::xoutil::XMLClass get_valid_id $page_id]'"
        } else {
            set refid_att ""

        }
        set entry "<item identifier='$itemid' $refid_att>\n\t<title>$label</title>\n"
        if {$cat_content ne ""} {set content "\n$cat_content"} else {set content ""}
        return "$entry $content</item>"
    }
















# fixme is this still needed

    ##############################
    #
    # TOC
    #
    ##############################

    Class ::xowiki::includelet::ScormOrganization \
        -superclass ::xowiki::includelet::toc

    ::xowiki::includelet::ScormOrganization instproc render_list {{-full false} pages} {
        my get_parameters
        # TODO clean up this method
        if {$open_page ne ""} {
          set allow_reorder ""
        } else {
          set allow_reorder [my page_reorder_check_allow -with_head_entries false $allow_reorder]
        }
        set tree [my build_tree -full $full -remove_levels $remove_levels \
              -book_mode $book_mode -open_page $open_page -expand_all $expand_all \
              $pages]
        my page_reorder_init_vars -allow_reorder $allow_reorder js last_level ID min_level
        return [$tree render -style scorm_navigation -context {min_level $min_level}]
    }





namespace eval ::xowiki::includelet {

  #
  # toc -- Table of contents
  #
  ::xowiki::IncludeletClass create scorm_organization \
      -superclass toc \
      -instmixin PageReorderSupport \
      -cacheable false -personalized false -aggregating true \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-style ""} 
          {-open_page ""}
          {-book_mode false}
          {-ajax false}
          {-expand_all false}
          {-remove_levels 0}
          {-category_id}
          {-locale ""}
          {-source ""}
          {-range ""}
	  {-allow_reorder ""}
        }}
        id
      }

#"select page_id,  page_order, name, title, \
#	(select count(*)-1 from xowiki_page_live_revision where page_order <@ p.page_order) as count \
#	from xowiki_page_live_revision p where not page_order is NULL order by page_order asc"

  scorm_organization instproc count {} {return [my set navigation(count)]}
  scorm_organization instproc current {} {return [my set navigation(current)]}
  scorm_organization instproc position {} {return [my set navigation(position)]}
  scorm_organization instproc page_name {p} {return [my set page_name($p)]}
  scorm_organization instproc cache_includelet_data {key} {
    append data \
	[list my array set navigation [my array get navigation]] \n \
	[list my array set page_name [my array get page_name]] \n
    return $data
  }

  scorm_organization proc anchor {name} {
    # try to strip the language prefix from the name
    regexp {^.*:([^:]+)$} $name _ name
    # anchor is used between single quotes
    regsub -all ' $name {\'} anchor
    return $anchor
  }

  scorm_organization instproc build_toc {package_id locale source range} {
    my instvar navigation page_name book_mode
    array set navigation {parent "" position 0 current ""}

    set extra_where_clause ""
    if {[my exists category_id]} {
      foreach {cnames extra_where_clause} [my category_clause [my set category_id]] break
    }
    foreach {locale locale_clause} \
        [::xowiki::Includelet locale_clause -revisions p -items p $package_id $locale] break
    #my msg locale_clause=$locale_clause

    if {$source ne ""} {
      my get_page_order -source $source
      set page_names ('[join [my array names page_order] ',']')
      set page_order_clause "and name in $page_names"
      set page_order_att ""
    } else {
      set page_order_clause "and not page_order is NULL"
      set page_order_att "page_order,"
    }

    set sql [::xo::db::sql select \
                 -vars "o.package_id, o.object_id, p.parent_id, page_id, $page_order_att name, p.title" \
                 -from "acs_objects o, xowiki_page_live_revision p" \
                 -where "o.package_id = $package_id AND o.object_id = p.revision_id \
			$page_order_clause \
			$extra_where_clause $locale_clause"]
            my msg "$sql"
    set pages [::xowiki::Page instantiate_objects -sql $sql]

    $pages mixin add ::xo::OrderedComposite::IndexCompare
    if {$range ne "" && $page_order_att ne ""} {
      foreach {from to} [split $range -] break
      foreach p [$pages children] {
	if {[$pages __value_compare [$p set page_order] $from 0] == -1
	    || [$pages __value_compare [$p set page_order] $to 0] > 0} {
	  $pages delete $p
	}
      }
    }

    $pages orderby page_order
    if {$source ne ""} {
      # add the page_order to the objects
      foreach p [$pages children] {
	$p set page_order [my set page_order([$p set name])]
      }
    }

    return $pages
  }

  scorm_organization instproc href {package_id book_mode name {parent_id ""}} {
    if {$book_mode} {
      set href [$package_id url]#[toc anchor $name]
    } else {
        if {$parent_id eq ""} {
            set href [$package_id pretty_link $name]
        } else {
            set href [$package_id pretty_link -parent_id $parent_id $name]
        }
    }
    return $href
  }

  scorm_organization instproc page_number {page_order remove_levels} {
    #my log "o: $page_order"
    set displayed_page_order $page_order
    for {set i 0} {$i < $remove_levels} {incr i} {
      regsub {^[^.]+[.]} $displayed_page_order "" displayed_page_order
    }
    return $displayed_page_order
  }

  scorm_organization instproc build_navigation {pages} {
    #
    # compute associative arrays open_node and navigation (position
    # and current)
    #
    my get_parameters
    my instvar navigation page_name
    array set navigation {position 0 current ""}

    # the top node is always open
    my set open_node() true
    set node_cnt 0
    foreach o [$pages children] {
      $o instvar page_order name
      incr node_cnt
      set page_name($node_cnt) $name
      if {![regexp {^(.*)[.]([^.]+)} $page_order _ parent]} {set parent ""}
      #
      # If we are on the provided $open_page, we remember our position
      # for the progress bar.
      set on_current_node [expr {$open_page eq $name} ? "true" : "false"]
      if {$on_current_node} {
        set navigation(position) $node_cnt
        set navigation(current) $page_order
      }
      if {$expand_all} {
        my set open_node($page_order) true
      } elseif {$on_current_node} {
        my set open_node($page_order) true
        # make sure to open all nodes to the root
        for {set p $parent} {$p ne ""} {} {
          my set open_node($p) true
          if {![regexp {^(.*)[.]([^.]+)} $p _ p]} {set p ""}
        }
      }
    }
    set navigation(count) $node_cnt
    #my log OPEN=[lsort [my array names open_node]]
  }

  scorm_organization instproc render_list {{-full false} pages} {
    my get_parameters
    my instvar navigation page_name
    #
    # Build a reduced toc tree based on pure HTML (no javascript or
    # ajax involved).  If an open_page is specified, produce an as
    # small as possible tree and omit all non-visible nodes.
    #
    if {$open_page ne ""} {
      # TODO: can we allow open_page and reorder?
      set allow_reorder ""
    } else {
      set allow_reorder [my page_reorder_check_allow $allow_reorder]
    }

    my page_reorder_init_vars -allow_reorder $allow_reorder js last_level ID min_level

    set css_class [expr {$min_level == 1 ? "page_order_region" : "page_order_region_no_target"}]
#my log allow_reorder=$allow_reorder,min_level=$min_level,css=$css_class
    set html "<UL class='$css_class'>\n"
    set prefix_js ""
    set html [my page_reorder_open_ul -min_level $min_level -ID $ID -prefix_js $prefix_js -1]
    set level 0
    foreach o [$pages children] {
      $o instvar page_order title name
      if {![regexp {^(.*)[.]([^.]+)} $page_order _ parent]} {set parent ""}
      set page_number [my page_number $page_order $remove_levels]

      set new_level [regsub -all {[.]} [$o set page_order] _ page_order_js]
      #my msg "[$o set page_order] [my exists open_node($parent)] || [my exists open_node($page_order)]"
      if {[my exists open_node($parent)] || [my exists open_node($page_order)]} {
        if {$new_level > $level} {
          for {set l $level} {$l < $new_level} {incr l} {
            regexp {^(.*)_[^_]+$} $page_order_js _ prefix_js
            append html [my page_reorder_open_ul -min_level $min_level -ID $ID -prefix_js $prefix_js $l]
          }
          set level $new_level
        } elseif {$new_level < $level} {
          for {set l $new_level} {$l < $level} {incr l} {append html "</ul>\n"}
          set level $new_level
        }
        set href [my href $package_id $book_mode $name "[$o parent_id]"]
        set highlight [if {$open_page eq $name} {set _ "style = 'font-weight:bold;'"} {}]
        set item_id [my page_reorder_item_id -ID $ID -prefix_js $prefix_js -page_order $page_order js]
        append html \
            "<li id='$item_id'>" \
            "<span $highlight>$page_number <a href='$href' target='sxorm_stage'>$title</a></span>\n"
      }
    }
    # close all levels
    for {set l 0} {$l <= $level} {incr l} {append html "</ul>\n"}
    if {$js ne ""} {append html "<script type='text/javascript'>$js</script>\n"}

    return $html
  }




  #
  # ajax based code for fade-in / fade-out
  #
  scorm_organization instproc yui_ajax {} {
    return "var [my js_name] = {

         count: [my set navigation(count)],

         getPage: function(href, c) {
             //console.log('getPage: ' + href + ' type: ' + typeof href) ;

             if ( typeof c == 'undefined' ) {

                 // no c given, search it from the objects
                 // console.log('search for href <' + href + '>');

                 for (i in this.objs) {
                     if (this.objs\[i\].ref == href) {
                        c = this.objs\[i\].c;
                        // console.log('found href ' + href + ' c=' + c);
                        var node = this.tree.getNodeByIndex(c);
                        if (!node.expanded) {node.expand();}
                        node = node.parent;
                        while (node.index > 1) {
                            if (!node.expanded) {node.expand();}
                            node = node.parent;
                        }
                        break;
                     }
                 }
                 if (typeof c == 'undefined') {
                     // console.warn('c undefined');
                     return false;
                 }
             }
             //console.log('have href ' + href + ' c=' + c);

             var transaction = YAHOO.util.Connect.asyncRequest('GET', \
                 href + '?template_file=view-page&return_url=' + href, 
                {
                  success:function(o) {
                     var bookpage = document.getElementById('book-page');
     		     var fadeOutAnim = new YAHOO.util.Anim(bookpage, { opacity: {to: 0} }, 0.5 );

                     var doFadeIn = function(type, args) {
                        // console.log('fadein starts');
                        var bookpage = document.getElementById('book-page');
                        bookpage.innerHTML = o.responseText;
                        var fadeInAnim = new YAHOO.util.Anim(bookpage, { opacity: {to: 1} }, 0.1 );
                        fadeInAnim.animate();
                     }

                     // console.log(' tree: ' + this.tree + ' count: ' + this.count);
                     // console.info(this);

                     if (this.count > 0) {
                        var percent = (100 * o.argument.count / this.count).toFixed(2) + '%';
                     } else {
                        var percent = '0.00%';
                     }

                     if (o.argument.count > 1) {
                        var link = o.argument.href;
                        var src = '/resources/xowiki/previous.png';
                        var onclick = 'return [my js_name].getPage(\"' + link + '\");' ;
                     } else {
                        var link = '#';
                        var onclick = '';
                        var src = '/resources/xowiki/previous-end.png';
                     }

                     // console.log('changing prev href to ' + link);
                     // console.log('changing prev onclick to ' + onclick);

                     document.getElementById('bookNavPrev.img').src = src;
                     document.getElementById('bookNavPrev.a').href = link;
                     document.getElementById('bookNavPrev.a').setAttribute('onclick',onclick);

                     if (o.argument.count < this.count) {
                        var link = o.argument.href;
                        var src = '/resources/xowiki/next.png';
                        var onclick = 'return [my js_name].getPage(\"' + link + '\");' ;
                     } else {
                        var link = '#';
                        var onclick = '';
                        var src = '/resources/xowiki/next-end.png';
                     }

                     // console.log('changing next href to ' + link);
                     // console.log('changing next onclick to ' + onclick);
                     document.getElementById('bookNavNext.img').src = src;
                     document.getElementById('bookNavNext.a').href = link;

                     document.getElementById('bookNavNext.a').setAttribute('onclick',onclick);
                     document.getElementById('bookNavRelPosText').innerHTML = percent;
                     //document.getElementById('bookNavBar').setAttribute('style', 'width: ' + percent + ';');
                     document.getElementById('bookNavBar').style.width = percent;

                     fadeOutAnim.onComplete.subscribe(doFadeIn);
  		     fadeOutAnim.animate();
                  }, 
                  failure:function(o) {
                     // console.error(o);
                     // alert('failure ');
                     return false;
                  },
                  argument: {count: c, href: href},
                  scope: [my js_name]
                }, null);

                return false;
            },

         treeInit: function() { 
            [my js_name].tree = new YAHOO.widget.TreeView('[my id]'); 
            [my js_name].tree.subscribe('clickEvent', function(oArgs) {
              var m = /href=\"(\[^\"\]+)\"/.exec(oArgs.node.html);
              [my js_name].getPage( m\[1\], oArgs.node.index); 
            });
            [my js_name].tree.draw();
         }

      };

     YAHOO.util.Event.addListener(window, 'load', [my js_name].treeInit);
"
  }

  scorm_organization instproc yui_non_ajax {} {
    return "
      var [my js_name]; 
      YAHOO.util.Event.onDOMReady(function() {
         [my js_name] = new YAHOO.widget.TreeView('[my id]'); 
         [my js_name].subscribe('clickEvent',function(oArgs) { 
            //console.info(oArgs);
            var m = /href=\"(\[^\"\]+)\"/.exec(oArgs.node.html);
            //console.info(m\[1\]);
            //window.location.href = m\[1\];
            return false;
	}); 
        [my js_name].render();
      });
     "
  }

  scorm_organization instproc build_tree {
    {-full false} 
    {-remove_levels 0} 
    {-book_mode false} 
    {-open_page ""} 
    {-expand_all false} 
    pages
  } {
    my instvar package_id
    set tree(-1) [::xowiki::Tree new -destroy_on_cleanup -orderby pos -id [my id]]
    set pos 0
    foreach o [$pages children] {
      $o instvar page_order title name parent_id
      if {![regexp {^(.*)[.]([^.]+)} $page_order _ parent]} {set parent ""}
      set page_number [my page_number $page_order $remove_levels]

      set level [regsub -all {[.]} [$o set page_order] _ page_order_js]
      if {$full || [my exists open_node($parent)] || [my exists open_node($page_order)]} {
        set href [my href $package_id $book_mode $name $parent_id]
	set is_current [expr {$open_page eq $name}]
        set is_open [expr {$is_current || $expand_all}]
        set c [::xowiki::TreeNode new -orderby pos -pos [incr pos] -level $level \
		   -object $o -owner [self] \
		   -label $title -prefix $page_number -href $href \
		   -highlight $is_current \
		   -expanded $is_open \
		   -open_requests 1]
        set tree($level) $c
	for {set l [expr {$level - 1}]} {![info exists tree($l)]} {incr l -1} {}
        $tree($l) add $c
	if {$is_open} {$c open_tree}
      }
    }
    return $tree(-1)
  }

  scorm_organization instproc render_yui_list {{-full false} pages} {
    my instvar js
    my get_parameters
    my instvar navigation page_name

    #
    # Render the tree with the yui widget (with or without ajax)
    #
    my set book_mode $book_mode
    if {$book_mode} {
      #my log "--warn: cannot use bookmode with ajax, resetting ajax"
      set ajax 0
    }
    my set ajax $ajax
    
    if {$ajax} {
      set js [my yui_ajax]
    } else {
      set js [my yui_non_ajax]
    }

    set tree [my build_tree -full $full -remove_levels $remove_levels \
		  -book_mode $book_mode -open_page $open_page -expand_all $expand_all \
		  $pages]

    set HTML [$tree render -style yuitree -js $js]
    return $HTML
  }

  scorm_organization instproc render_list {{-full false} pages} {
    my get_parameters

    #
    # Build a reduced toc tree based on pure HTML (no javascript or
    # ajax involved).  If an open_page is specified, produce an as
    # small as possible tree and omit all non-visible nodes.
    #
    if {$open_page ne ""} {
      # TODO: can we allow open_page and reorder?
      set allow_reorder ""
    } else {
      set allow_reorder [my page_reorder_check_allow -with_head_entries false $allow_reorder]
    }

    set tree [my build_tree -full $full -remove_levels $remove_levels \
		  -book_mode $book_mode -open_page $open_page -expand_all $expand_all \
		  $pages]

    my page_reorder_init_vars -allow_reorder $allow_reorder js last_level ID min_level
    set js "\nYAHOO.xo_page_order_region.DDApp.package_url = '[$package_id package_url]';"
    set HTML [$tree render -style listdnd -js $js -context {min_level $min_level}]
    
    return $HTML
  }


  scorm_organization instproc include_head_entries {} {
    my instvar style renderer
    ::xowiki::Tree include_head_entries -renderer $renderer -style $style;# FIXME general
  }

  scorm_organization instproc initialize {} {
    my get_parameters

    set list_mode 0
    switch -- $style {
      "menu" {set s "menu/"; set renderer yuitree}
      "folders" {set s "folders/"; set renderer yuitree}
      "list"    {set s ""; set list_mode 1; set renderer list}
      "default" {set s ""; set renderer yuitree}
    }
    my set renderer $renderer
    my set style $s
    my set list_mode $list_mode
  }

  scorm_organization instproc render {} {
    my get_parameters

    if {![my exists id]} {my set id [::xowiki::Includelet html_id [self]]}
    if {[info exists category_id]} {my set category_id $category_id}

    #
    # Collect the pages
    #
    set pages [my build_toc $package_id $locale $source $range]
    #
    # Build the general navigation structure using associative arrays
    #
    my build_navigation $pages
    #
    # Call a render on the created structure
    #
    if {[my set list_mode]} {
      return [my render_list $pages]
    } else {
      return [my render_yui_list -full true $pages]
    }
  }
}

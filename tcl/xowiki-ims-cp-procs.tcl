::xo::library doc {

    IMS CP Support for XoWiki

    @see http://www.imsglobal.org/content/packaging/
    @creation-date 2009
    @author Michael Aram
}

# TODO: Enforce the suffix .html when pages are created!!! We need that
# TODO: Automatically create xoscorm-index.html page (based on prototype)
# TODO: Make the frame (stage) resizeable
# TODO: Show Organizations switch only when more then one org 
# TODO: Handle language prefixes. for now, they are just removed. (also file:)
# TODO: Do we want to add .html to all pages?
# TODO: I somehow broke the mime_types: Remove */* 

# FIXME: With "with_user_tracking" parameter set, we get an error when emptying and importing.
# the error comes from "record_last_visited" (but it works anyway)

::xo::library require -absolute t [acs_root_dir]/packages/xowiki/tcl/xowiki-procs
::xo::library require -absolute t [acs_root_dir]/packages/xolrn/tcl/xolrn-procs

namespace eval ::xowiki::ims {}
namespace eval ::xowiki::ims::cp {

    ::xo::PackageMgr create ::xowiki::ims::cp::Package \
        -package_key "xowiki-ims-cp" \
        -pretty_name "IMS CP Service for XoWiki" \
        -table_name "xowiki_ims_cp" \
        -superclass ::xowiki::Package

    Package ad_instproc initialize {} {
        mixin ::xowf::WorkflowPage to every FormPage
      } {
        # This method is called, whenever an xowf package is initialized.
        next
        ::scorm::Organization instmixin add ::xowiki::ims::cp::Organization
    }

    Package instmixin add ::xolrn::ResolverMixin


    Package instproc generate_manifest {} {
        # Create a new Manifest from scratch
        set res [list]
        foreach fileobj [my get_wiki_content_as_fileobjects] {
            if {[$fileobj exists is_wikifile] && [$fileobj set name] != "imsmanifest.xml"} {
                set f [::ims::cp::InternalFile create [my autoname internalfile] -destroy_on_cleanup -href "download/file/[$fileobj get_cp_filename]"]
            } else {
                set f [::ims::cp::InternalFile create [my autoname internalfile] -destroy_on_cleanup -href "[$fileobj get_cp_filename]"]
            }
            # TODO this is only good for our wiki-orga and dirty
            if { [$f set href] eq "xoscorm-index.html" } {
                lappend res [::scorm::Resource create xoscorm-index -adlcp:scormtype "sco" -destroy_on_cleanup -files $f]
            } else {
                set itemid [::xoutil::XMLClass get_valid_id [[$fileobj set critem] revision_id]]
                lappend res [::scorm::Resource create [my autoname resource] -identifier $itemid -adlcp:scormtype "sco" -destroy_on_cleanup -files $f]
            }
        }

        set wikiorg [my get_wiki_organization]
        set bookorg [my get_book_organization]

        ::scorm::Manifest man -destroy_on_cleanup -resources $res -temp true -organizations [list $bookorg $wikiorg]

        man set package_id [my set id]
        man set folder_id  [my set folder_id]
        man mixin add ::xowiki::ims::cp::File

        # Check if there is a Manifest in the xowiki instance
        set critem [my get_page_from_name -name "file:imsmanifest.xml"]
        if {$critem ne ""} {
            $critem set import_file [man set location]
            $critem save
        } else {
            man to_xowiki
        }
    }

    Package ad_instproc get_wiki_organization {} {
        returns a simple SCORM Organization, that contains only an entry page sco
      } {
        set ::wikiname [my set instance_name]

        ::scorm::Organization create [self]::wiki_organization -contains {
            ::ims::cp::Title t -text "$::wikiname"
            ::ims::cp::Item xoscorm-item-initialize -identifierref "xoscorm-index" -contains {
                ::ims::cp::Title t1 -text "Enter Wiki"
            }
        }

        return [self]::wiki_organization
    }
    Package ad_instproc get_book_organization {} {
        returns the book-toc as scorm org
      } {

        set package_id [my id]
        #FIXME The includelet requires a parent object due to a bug(?), because it can also be a dummy object
        BookOrganization create [self]::book_organization -package_id $package_id -set expand_all true -set style list

        [self]::book_organization initialize
        [self]::book_organization set id "book[my id]"

        [self]::book_organization build_navigation [[self]::book_organization build_toc $package_id en_US "" ""]
        set xml [[self]::book_organization render_as_scorm_organization -full true  [[self]::book_organization build_toc $package_id en_US "" ""]]

        set doc [dom parse $xml]

        ::scorm::Organization create [self]::book_org -dom [$doc documentElement]

        return [self]::book_org
    }

    Package ad_instproc get_wiki_content_as_fileobjects {} {
        TODO: CLEANUP
      } {
        # Get all Pages
        set pageids [list]
        set sql [::xowiki::Page instance_select_query -with_subtypes 1 -folder_id [my set folder_id] -with_children true]
        db_foreach retrieve_instances $sql {
             # not the folder object 
             if {[regexp {::.*} $name]} {
                 continue
             }
             lappend pageids $item_id
        }

        set files [list]

        foreach item_id $pageids {
            set cri [::xo::db::CrClass get_instance_from_db -item_id $item_id]
            if {[file isfile "[acs_root_dir]/content-repository-content-files[$cri set text]"]} {
                # The actual file
                set f [File create [my autoname wikifile] -location "[acs_root_dir]/content-repository-content-files[$cri set text]"]
                $f set name [regsub "^file:" [$cri set name] ""]
                $f set mime_type [$cri set mime_type]
                # MARK THOSE THAT SHOULD GO INTO download/file
                $f set is_wikifile true
                # associate the critem for convenience
                $f set critem $cri
                #$f set_extension_based_on_mimetype
                lappend files $f

                # The file overview page
                #set f [::xoutil::TempFile create [my autoname exportfile]]
                #$f set name [regsub "^file:" [$cri set name] ""]
                #lappend files $f
            } else {
                #TODO do we still/really need that?
                $cri set absolute_links 0
                set f [File create [my autoname exporttmpfile] -temp true ]
                $f set critem $cri
                $f set mime_type [$cri set mime_type]
                $f set name [regsub "^en:" [$cri set name] ""]

                $f set content [my get_page_content $cri]

                $f save
                lappend files $f
            }
        }
        return $files
    }

    Class LinkRewriter
    LinkRewriter instproc pretty_link args {
        # we need a relative URL
        set package_prefix "[my set package_url]"
        set absolute_internal_url [next]
        set relative_url [regsub $package_prefix $absolute_internal_url ""]
        return $relative_url
    }

    Package ad_instproc get_page_content {cr_item} {
      This method gets the contents of the page, but in contrast to normal xowiki "rendering"
      it changes the link-generation process so that it generates relative urls.
      Furthermore, it tries to detect, whether the page was originally imported, which means it
      contains a "full html page", or whether it is an ordinary xowiki page, which only contains
      an html fragment. In the latter case, the page content is wrapped.
      } {
        my mixin add ::xowiki::ims::cp::LinkRewriter
        set content ""
        # Fill the file with content using "render"
        set content [$cr_item render -with_footer false]

            # Using "view" method could be an option?
            #::xo::ConnectionContext require -url [ad_conn url]
            #::xo::cc set_parameter template_file "/packages/xowiki-ims-cp/www/view-sco"
            #$f set content [$cri view]
        my mixin delete ::xowiki::ims::cp::LinkRewriter
        return $content
    }



    Package ad_instproc export_wiki_as_cp {} {
        This is the trigger function for exporting a wiki instance as content package.
        } {
        my generate_manifest
        set fileobjects [my get_wiki_content_as_fileobjects]
        #ds_comment "[my serialize]"
        set zipfilename [regsub {/$} [my set package_url] ""]
        ContentPackage create [self]::cp -location "[acs_root_dir]/packages/ims-cp[ns_tmpnam]$zipfilename"
        # Create folders for xowikis "proprietary" "download/file" links
        ::xoutil::Folder create [self]::cp::download -name "download" -parent_folder [self]::cp
        ::xoutil::Folder create [self]::cp::download::file -name "file" -parent_folder [self]::cp::download
        foreach fileobject $fileobjects {
            if {[$fileobject exists is_wikifile] && [$fileobject set name] != "imsmanifest.xml"} {
                [self]::cp::download::file add_file $fileobject
            } else {
                [self]::cp add_file $fileobject
            }
        }
        [self]::cp add_file [::xoutil::File create getapi -location "[acs_root_dir]/packages/scorm/www/resources/1.2/get_api.js"]
        set pif [[self]::cp pack]
        $pif deliver
    }

    Package ad_instproc has_manifest {} {
      Checks whether this XoWiki instance contains an ::xowiki::File named imsmanifest.xml
      } {
        return [expr { [my get_page_from_name -name "file:imsmanifest.xml"] eq "" ? false : true }]
    }

    Package ad_instproc get_manifest {} {
        Returns a fully-built manifest object based upon the xml inside the imsmanifest.xml file that lies in the current instance
      } {
        set page [my get_page_from_name -name "file:imsmanifest.xml"]
        return [::scorm::Manifest create [self]::manifest -location [$page full_file_name]]
    }

    Package ad_instproc decorate_page_order {} {
        Decorate the pages inside this instance with page_order values according to the manifest file
      } {
        if {![my has_manifest]} {
            my msg "no manifest"
            return ""
        }
        set m [my get_manifest]
        set o [$m get_default_or_implicit_organization]
        $o decorate_page_order

        foreach item [$o all_children_of_type Item] {
            # Get the Resource attached to the Item, if any
            if {[$item exists identifierref]} {
                set r [$m get_element_by_identifier [$item set identifierref]]
                foreach f [${r}::files children] {
                    my msg "candidate [$f set href] "
                    # We only attach the page order to the file that has the same href as the resource
                    if {[$r set href] eq [$f set href]} {
                        my msg "decorate: [$f set href] "
                        $f set title "[$item title]"
                        $f set page_order [$item set page_order]
                    }
                    #TODO: Theoretically the href could have spaces (problem with array)"
                    my set imsfiles([$f set href]) $f
                    #my log "** preparing file [$f set href] in cp [my set location] for import"
                }
            }
        }

        foreach imsfilehref [my array names imsfiles] {


            my msg "wanna decorate $imsfilehref"
            set page [my resolve_page $imsfilehref view]

            if {[[my set imsfiles($imsfilehref)] exists page_order]} {
                my msg "-> [my resolve_page $imsfilehref dummy]"
                $page set page_order [[my set imsfiles($imsfilehref)] set page_order]
                $page set title [[my set imsfiles($imsfilehref)] set title]
            }
            $page save
        }
    }



    #
    # This is a copy of XoWikis "resolve page" method. We just added the emphasized part
    #

# TODO: is this still necessary?

  Package instproc resolve_page {{-use_search_path true} {-simple false} -lang object method_var} {
    my log "resolve_page '$object'"
    upvar $method_var method
    my instvar id

    # get the default language if not specified
    if {![info exists lang]} {
      set lang [my default_language]
    }

    #
    # First, resolve package level methods, 
    # having the syntax PACKAGE_URL?METHOD&....
    #

    if {$object eq ""} {
      #
      # We allow only to call methods defined by the policy
      #
      set exported [[my set policy] defined_methods Package]
      foreach m $exported {
	#my log "--QP my exists_query_parameter $m = [my exists_query_parameter $m] || [my exists_form_parameter $m]"
        if {[my exists_query_parameter $m] || [my exists_form_parameter $m]} {
          set method $m  ;# determining the method, similar file extensions
          return [self]
        }
      }
    }

    if {[string match "//*" $object]} {
        # we have a reference to another instance, we cant resolve this from this package.
      # Report back not found
      return ""
    }

    #my log "--o object is '$object'"
    if {$object eq ""} {
      # we have no object, but as well no method callable on the package
      set object [$id get_parameter index_page "index"]
      #my log "--o object is now '$object'"
    }
    #
    # second, resolve object level
    #
    set page [my resolve_request -default_lang $lang -simple $simple -path $object method]

    ###############################################################
    ###############################################################
    ###############################################################
    # Check if we have a file with same name
    # TODO - check if is this obsolete NOW??
    set filepage [my resolve_request -default_lang "download/file" -simple $simple -path $object method]
    if {$page eq "" && $filepage ne ""} {
        return $filepage
    }
    ###############################################################
    ###############################################################
    ###############################################################
    
    #my log "--o resolving object '$object' -default_lang $lang -simple $simple returns '$page'"
    if {$simple || $page ne ""} {
      return $page
    }



    # stripped object is the object without a language prefix
    set stripped_object $object
    regexp {^..:(.*)$} $object _ stripped_object

    # try standard page
    set standard_page [$id get_parameter ${object}_page]
    if {$standard_page ne ""} {
      set page [my resolve_request -default_lang [::xo::cc lang] -path $standard_page method]
      #my msg "--o resolving standard_page '$standard_page' returns $page"
      if {$page ne ""} {
        return $page
      }

      # Maybe we are calling from a different language, but the
      # standard page with en: was already instantiated.
      set standard_page "en:$stripped_object"
      set page [my resolve_request -default_lang en -path $standard_page method]
      #my msg "resolve -default_lang en -path $standard_page returns --> $page"
      if {$page ne ""} {
        return $page
      }
    }

    # Maybe, a prototype page was imported with language en:, but the current language is different
    if {$lang ne "en"} {
      set page [my resolve_request -default_lang en -path $stripped_object method]
      #my msg "resolve -default_lang en -path $stripped_object returns --> $page"
      if {$page ne ""} {
	return $page
      }
    }

    if {$use_search_path} {
      # Check for this page along the package path
      foreach package [my package_path] {
        set page [$package resolve_page -simple $simple -lang $lang $object method]
        if {$page ne ""} {
        return $page
        }
      }
    }

    #my msg "we have to try to import a prototype page for $stripped_object"
    set page [my import-prototype-page $stripped_object]
    if {$page ne ""} {
      return $page
    }
    my log "no prototype for '$object' found"
    return $page
  }

    ##############################
    #
    # TOC
    #
    ##############################

    Class BookOrganization -superclass ::xowiki::includelet::toc

    BookOrganization instproc render_as_scorm_organization {{-full false} pages} {
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
        return [$tree render -style scorm_organization -context {min_level $min_level}]
    }

  ::xowiki::TreeRenderer create ::xowiki::TreeRenderer=scorm_organization
  ::xowiki::TreeRenderer=scorm_organization proc include_head_entries {args} {
  }
  ::xowiki::TreeRenderer=scorm_organization proc render {tree} {
    return "<organization id='xowiki_book'>\n<title>Book Organization</title>[next]</organization>"
  }
  ::xowiki::TreeRenderer=scorm_organization instproc render_item {{-highlight:boolean false} item} {
   # $item instvar title prefix suffix href
   # append entry \
   # [::xowiki::Includelet html_encode $prefix] \
   # "<a href='$href'>" \
   # [::xowiki::Includelet html_encode $title] \
   # "</a>[::xowiki::Includelet html_encode $suffix]"
   # return "<itemo>$entry</itemo>\n"
  }
  ::xowiki::TreeRenderer=scorm_organization instproc render_node {{-open:boolean false} cat_content} {
    set cl [lindex [my info precedence] 0]
    set o_atts [lindex [$cl li_expanded_atts] [expr {[my expanded] ? 0 : 1}]]
    set h_atts [lindex [$cl highlight_atts] [expr {[my highlight] ? 0 : 1}]]
    set u_atts ""

    if {[my exists li_id]} {append o_atts " id='[my set li_id]'"}
    if {[my exists ul_id]} {append u_atts " id='[my set ul_id]'"}
    if {[my exists ul_class]} {append u_atts " class='[my set ul_class]'"}

    set label [::xowiki::Includelet html_encode [my label]]
    set itemid [::xoutil::XMLClass get_valid_id [self]]
    set refid [::xoutil::XMLClass get_valid_id [[my object] set page_id]]

	set entry "<item identifier='$itemid' identifierref='$refid'>\n\t<title>[my prefix] $label</title>"
    if {$cat_content ne ""} {set content "\n$cat_content"} else {set content ""}
    #return "<item $o_atts><title $h_atts>[my prefix] $entry</title>$content"
    return "$entry \n $content</item>"
  }



    #############################
    #
    # CONTENT PACKAGE (XOWIKI)
    #
    #############################


    # TODO - Dont make a subclass - make a Service Contract for import
    Class ContentPackage -superclass ::scorm::ContentAggregationPackage

    # DEPRECATED - We now mount into the current instance
    ContentPackage instproc mount_to_site_node {} {
        # FIXME - For testing we mount under /cps 
        my set node_name "[my name][clock seconds]"
        my set url "/cps/[my set node_name]"
        set site_node_id [site_node::instantiate_and_mount -package_key xowiki -parent_node_id 3081 -node_name [my set node_name]]
        #ds_comment "sitenode: $site_node_id"
        # reeturns null why??
        #my set url [site_node::get_url -node_id $site_node_id]
        #ds_comment "URL: [my set url]"
        #my package_id [::xowiki::Package require [my set site_node_id]]
    }

    # todo move this elsewhere
    ContentPackage instproc empty_target_wiki {} {
        set sql [::xowiki::Page instance_select_query -with_subtypes 1 -folder_id [[my set xo_pkg_obj] set folder_id] -with_children true]
        db_foreach retrieve_instances $sql {
            # preserve the folder object - we get errors if not
             if {$object_type eq "::xowiki::FormPage" || $object_type eq "::xowiki::Form"} {
                 continue
             }
             if {$name eq "::[[my set xo_pkg_obj] set folder_id]"} {
                 continue
             }
          permission::require_write_permission -object_id $item_id
          ::[my set xo_pkg_obj] delete -item_id $item_id -name $name
        }
    }


    Class Organization

    Organization instproc decorate_page_order {} {
        set prefix ""
        set count 1
        foreach item [my children_of_type Item] {
            $item decorate_page_order $prefix $count
            incr count
        }
    }

    ::ims::cp::Organization instmixin add ::xowiki::ims::cp::Organization

    Class Item

    Item instproc decorate_page_order {prefix count} {
        my set page_order $prefix$count
        set subcount 1
        foreach item [my children_of_type Item] {
            $item decorate_page_order [my set page_order]. $subcount
            incr subcount
        }
    }

    ::ims::cp::Item instmixin add ::xowiki::ims::cp::Item





    # By default, we import only those items, that are mentioned in the Manifest, which 
    # is correct. Using the switch, we import everything that was in the zippackage.
    ContentPackage instproc import_to_wiki_instance { {-include_dead_files true} } {
        # DEPRECATED - new IMPORTER
        my instvar xo_pkg_obj


        # First get ALL files
        # (many CPs include additional files)

        #  if {$include_dead_files eq true} {
        #      foreach realfile [[self]::files children] {
        #          $realfile set package_id [$xo_pkg_obj set id]
        #          $realfile set folder_id  [$xo_pkg_obj set folder_id]
        #          $realfile set page_order ""
        #          $realfile set title [$realfile set name]
        #          $realfile mixin add ::xowiki::ims::cp::File
        #          $realfile to_xowiki
        #      }
        #  }


        set m [self]::manifest
        set o [$m get_default_or_implicit_organization]
        $o decorate_page_order

        foreach item [$o all_children_of_type Item] {
            # Get the Resource attached to the Item
            set r [$m get_element_by_identifier [$item set identifierref]]
            foreach f [${r}::files children] {
                # We only attach the page order to the file that has the same href as the resource
                if {[$r set href] eq [$f set href]} {
                    $f set title "[$item title]"
                    $f set page_order [$item set page_order]
                }
                #TODO: Theoretically the href could have spaces (problem with array)"
                my set imsfiles([$f set href]) $f
                my log "** preparing file [$f set href] in cp [my set location] for import"
            }
        }

        foreach imsfilehref [my array names imsfiles] {
#            set realfile [[my set imsfiles($imsfilehref)] set fileobj]
            set realfile [::xoutil::File create [self]::[my autoname F_] -location [file join [my set location] $imsfilehref]]
            $realfile set package_id [$xo_pkg_obj set id]
            $realfile set folder_id  [$xo_pkg_obj set folder_id]
            if {[[my set imsfiles($imsfilehref)] exists page_order]} {
                $realfile set page_order [[my set imsfiles($imsfilehref)] set page_order]
                $realfile set title [[my set imsfiles($imsfilehref)] set title]
            } else {
                $realfile set page_order ""
                $realfile set title [$realfile set name]

            }
            $realfile mixin add ::xowiki::ims::cp::File
            $realfile to_xowiki
        }



       #   # TODO dirty
       #   if {$include_dead_files eq true} {
       #       ns_log notice "LIVE oNLY"
       #       foreach imsfile [my get_unique_file_objects] {
       #           set realfile [$imsfile set fileobj]
       #           $realfile set package_id [$xo_pkg_obj set id]
       #           $realfile set folder_id  [$xo_pkg_obj set folder_id]
       #           $realfile mixin add ::xowiki::ims::cp::File
       #           #$realfile to_xowiki
       #       }
       #   } else {
       #       ns_log notice "DEAD TOO"
       #       # FIXME this is only the first level
       #       foreach realfile [[self]::files children] {
       #           my log "FILE $realfile ready to import"
       #           $realfile set package_id [$xo_pkg_obj set id]
       #           $realfile set folder_id  [$xo_pkg_obj set folder_id]
       #           $realfile mixin add ::xowiki::ims::cp::File
       #           $realfile to_xowiki
       #       }
       #   }
    }


    ###########################
    #
    # FILE
    #
    # ::xowiki::ims::cp::File
    #
    ###########################


    Class File -superclass ::xoutil::File

    #::xowiki::File instmixin add ::xowiki::ims::cp::File

    File instproc get_cp_filename {} {
        set filename [my name]
        regsub -all "en:" $filename "" filename
        regsub -all "file:" $filename "" filename
        return $filename

    }

    # TODO This is dirty - use CR functions??
    File instproc write_to_file { {-path "/tmp"} } {
        file copy -force [acs_root_dir]/content-repository-content-files[my text] "$path/[my get_cp_filename]"
        return "$path/[my get_cp_filename]"
    }

    File instproc to_xowiki {} {
        #ds_comment "TO WIKI: [my serialize]"
        #FIXME

        set package_id [my set package_id]
        set folder_id [my set folder_id]
        #set package_id [::ims::cp::controller::pkg set xo_pkg_obj]
        #set folder_id [[::ims::cp::controller::pkg set xo_pkg_obj] folder_id]
            switch -- [my mime_type] {
                "text/html" {
                    #ds_comment "HTML: [my serialize]"
                    set o [::xowiki::Page new -destroy_on_cleanup \
                        -set text [list [my set content] [my set mime_type]] \
                        -set title [my set title] \
                        -set page_order [my set page_order] \
                        -name [my set name] \
                        -parent_id $folder_id \
                        -package_id $package_id]
                    $o save_new
                }
                "text/plain" {
                    #ds_comment "PLAIN: [my serialize]"
                    set o [::xowiki::PlainPage new -destroy_on_cleanup \
                        -set text [list [my set content] [my set mime_type]] \
                        -set title [my set name] \
                        -name [my set name] \
                        -parent_id $folder_id \
                        -package_id $package_id]
                    $o save_new
                }
                default {
                   #ds_comment "FILE: [my serialize]"
                   set f [::xowiki::File new -destroy_on_cleanup \
                        -title [my set name] \
                        -name "file:[my set name]" \
                        -parent_id $folder_id \
                        -mime_type [my set mime_type] \
                        -package_id $package_id]
                   $f set import_file [my set location]
                   $f save_new

                }
            }
    }
}


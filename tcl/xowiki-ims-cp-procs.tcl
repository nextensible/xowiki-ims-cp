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
# TODO: I somehow broke the mime_types: Remove */* (really - still??)

::xo::library require -package xowiki xowiki-procs
::xo::library require -package xolrn xoutil-procs
::xo::library require -package scorm scorm-cam-procs

namespace eval ::xowiki::ims {}
namespace eval ::xowiki::ims::cp {

    ::xo::PackageMgr create ::xowiki::ims::cp::Package \
        -package_key "xowiki-ims-cp" \
        -pretty_name "IMS CP Service for XoWiki" \
        -table_name "xowiki_ims_cp" \
        -superclass ::xowiki::Package

    Package ad_instproc initialize {} {
      } {
        next
        ::ims::cp::Item instmixin add ::xowiki::ims::cp::Item
        ::scorm::Organization instmixin add ::xowiki::ims::cp::Organization
    }


    # TODO Clean this up - there are more beautiful functions now
    Package ad_instproc generate_manifest {} {
        Update the current existing manifest (or create one from scratch if it doesnt exists).
        Organizations coming from imported packages are preserved.
        Three "self-made" organizations are included:
        <ul>
        <li>Book Organization
        <li>Category Organization
        <li>Wiki Organization (offers just an entry to the wiki)
        </ul>
      } {
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

        set all_orgas [list]

        set current_orgas [[my get_manifest]::organizations children]

        # Add the Organizations, that we did not create ourselves (import), as they are.
        foreach orga $current_orgas {
            if {[regexp "sxorm" [$orga identifier]]} { continue }
            lappend all_orgas $orga
        }


        foreach catorg [my get_category_organizations] {
            lappend all_orgas $catorg
        }
        lappend all_orgas [my get_wiki_organization]
        lappend all_orgas [my get_book_organization]

        ::scorm::Manifest man -destroy_on_cleanup -resources $res -temp true -organizations $all_orgas

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

    Package ad_instproc get_category_organizations {} {
        returns the cat-tree as scorm org
      } {

        set package_id [my id]
        #FIXME The includelet requires a parent object (due to a bug(?), because it can also be a dummy object)
        ::xowiki::includelet::CategoryOrganization create [self]::cat_organization -package_id $package_id -set expand_all true
        [self]::cat_organization initialize
        set xml [[self]::cat_organization render]

        set doc [dom parse $xml]

        set catorgas [list]
        set counter 0
        foreach catorgdom [[$doc documentElement] childNodes] {
            lappend catorgas [::scorm::Organization new -identifier "sxorm-cat-org-$counter" -dom $catorgdom]
            incr counter
        }
        return $catorgas
    }

    Package ad_instproc get_wiki_organization {} {
        returns a simple SCORM Organization, that contains only an entry page sco
      } {
        set ::wikiname [my set instance_name]

        ::scorm::Organization create [self]::wiki_organization -identifier "sxorm-wiki-org" -contains {
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
        #FIXME The includelet requires a parent object (due to a bug(?), because it can also be a dummy object)
        ::xowiki::includelet::BookOrganization create [self]::book_organization -package_id $package_id -set expand_all true
        [self]::book_organization initialize
        #[self]::book_organization set id "book[my id]"
        #[self]::book_organization build_navigation [[self]::book_organization build_toc $package_id en_US "" ""]
        #set xml [[self]::book_organization render -full true [[self]::book_organization build_toc $package_id en_US "" ""]]
        set xml [[self]::book_organization render]

        set doc [dom parse $xml]

        ::scorm::Organization create [self]::book_org -identifier "sxorm-book-org" -dom [$doc documentElement]

        return [self]::book_org
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


    Package ad_instproc get_childpages {-crfolder_id} {
        #TODO
    } {
        set sql [::xowiki::Page instance_select_query -with_subtypes 1 -folder_id $crfolder_id -with_children false]
        db_foreach retrieve_instances $sql {
             # not the folder object 
             if {[regexp {::.*} $name]} { continue }
             lappend pages [::xo::db::CrClass get_instance_from_db -item_id $item_id]
        }
        return $pages
    }

    Package ad_instproc get_subfolders {-crfolder_id} {
        #TODO
    } {
        set crfolders [list]
        set sql [::xo::db::CrFolder instance_select_query -with_subtypes 1 -folder_id $crfolder_id -with_children false]
        db_foreach retrieve_instances $sql {
             lappend crfolders [::xo::db::CrFolder get_instance_from_db -item_id $item_id]
        }
        return $crfolders
    }

    Package ad_instproc export_scorm_cp {} {
        new test
      } {
        set zipfilename [regsub {/$} [my set package_url] ""]
        set cp [ContentPackage create [self]::cp -location "[acs_root_dir]/packages/ims-cp[ns_tmpnam]$zipfilename"]

        my add_pages_to_fs_folder -crfolder_id [my folder_id] -fsfolder $cp

        foreach crfolder "[my get_subfolders -crfolder_id [my folder_id]]" {
            my build_fsfolder -cr_folder $crfolder -parent_folder $cp
        }
        set pif [[self]::cp pack]
        $pif deliver
    }

    Package ad_instproc build_fsfolder {-cr_folder -parent_folder} {} {
        set f [::xoutil::Folder new -name "[$cr_folder name]" -parent_folder $parent_folder]
        my msg "[$f serialize]"
        my add_pages_to_fs_folder -crfolder_id [$cr_folder folder_id] -fsfolder $f
        foreach sub_crfolder "[my get_subfolders -crfolder_id [$cr_folder folder_id]]" {
            my build_fsfolder -cr_folder $sub_crfolder -parent_folder $f
        }
    }

    Package ad_instproc add_pages_to_fs_folder {-crfolder_id -fsfolder} {} {
        foreach page [my get_childpages -crfolder_id $crfolder_id] {
            set f [File new -temp]
            if {[$page istype ::xowiki::File]} {
                $f set location "[$page full_file_name]"
                $f set name [regsub "^file:" [$page set name] ""]
                $f set mime_type [$page mime_type]
            } elseif {[$page istype ::xowiki::Page]} {
                $f set location [ns_tmpnam]
                $f set name [regsub "^..:" [$page set name] ""]
                $f set mime_type [$page mime_type]
                $f set content [$page render]
                $f save
            } else {
                my msg "[$f serialize]"
            }
            $fsfolder add_file $f
        }
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


                        set folder_attributes [list creation_user title parent_id label \
                                            "to_char(last_modified,'YYYY-MM-DD HH24:MI:SS') as last_modified" ]
                        set folder_id [my folder_id]

                        set folder_sql [::xo::db::CrFolder instance_select_query \
                                 -folder_id $folder_id \
                                 -select_attributes $folder_attributes \
                                 -with_subtypes true \
                                 -with_children false \
                                 -orderby ci.name \
                                ]

                        db_foreach folder_select $folder_sql {
                                my msg $name
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
    Package ad_instproc has_manifest {} {
      Checks whether this XoWiki instance contains an ::xowiki::File named imsmanifest.xml
      } {
        return [expr { [my get_page_from_name -name "file:imsmanifest.xml"] eq "" ? false : true }]
    }

    Package ad_instproc get_manifest {} {
        Returns a fully-built manifest object based upon the xml inside the imsmanifest.xml file that lies in the current instance
        TODO Caching
      } {
         if {[Object isobject [self]::manifest]} {
            return [self]::manifest
          }
        set page [my get_page_from_name -name "file:imsmanifest.xml"]
        return [::scorm::Manifest create [self]::manifest -location [$page full_file_name]]
    }

    Package ad_instproc get_page_for_item {item} {
        Returns 
      } {
        set href [my get_href_for_item -item $item]
        my log "\n Item $item has href $href"
        set page [expr {$href eq "" ? "" : [my resolve_page $href view]}]
        return $page
    }

    # todo: remove the manifest arg
    Package instproc get_href_for_item {-item} {
        set m [my get_manifest]
        # Get the Resource attached to the Item, if any
        if {[$item exists identifierref]} {
            set r [$m get_element_by_identifier [$item set identifierref]]
            foreach f [${r}::files children] {
                if {[$r set href] eq [$f set href]} {
                    return [$r set href]
                }
            }
        }
        return ""
    }

    Package ad_instproc generate_category_organization {} {
        Gen Cat based on org
      } {
        if {![my has_manifest]} {
            my msg "no manifest"
            return ""
        }
        # TODO import all - not only the default (easy)
        set m [my get_manifest]
        set o [$m get_default_or_implicit_organization]

        set cat_tree_id [category_tree::add -name "[$o title]" -description "SCORM Organization of Wiki [my id]" -context_id [my id]]
        category_tree::map -tree_id $cat_tree_id -object_id [my id]
        $o generate_category -cat_tree_id $cat_tree_id
        my resolve_dependencies

        my map_items_to_categories
    }

    Package ad_instproc map_items_to_categories {} {
        maps the page associated with the file, which is referenced by a resource that is referenced by an item :-) to a category
      } {
        set m [my get_manifest]
        set o [$m get_default_or_implicit_organization]

        foreach item [$o all_children_of_type Item] {
            set page [my get_page_for_item $item]
            if {$page ne ""} {
                my msg "Mapping [$page name] to category [$item set __item_cat_id]"
                category::map_object -object_id [$page item_id] [$item set __item_cat_id]
            }
        }
    }


    Package ad_instproc resolve_dependencies {} {
        Replace all Dependency instances in the composite with their associated resources
      } {
        set m [my get_manifest]
        foreach r [${m}::resources children] {
            # Get the required Resource
            foreach d [${r}::dependencies children] {
                set res [$m get_element_by_identifier [$d set identifierref]]
                foreach depfile [${res}::files children] {
                    ${r}::files add $depfile
                }
            }
        }
    }

    Package ad_instproc decorate_titles {} {
        Decorate the pages inside this instance with titles from manifest items
      } {
        if {![my has_manifest]} {
            my msg "no manifest"
            return ""
        }
        set m [my get_manifest]
        set o [$m get_default_or_implicit_organization]
        $o decorate_page_order

        # First, resolve dependencies
        my resolve_dependencies
        # TODO: resolve dependencies only once

        foreach item [$o all_children_of_type Item] {
            set page [my get_page_for_item $item]
            if {$page ne ""} {
                my msg "Decorating [$page name] with title [$item title]"
                $page set title [$item title]
                $page save
            }
        }
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

        # First, resolve dependencies

        my resolve_dependencies
        #foreach r [${m}::resources children] {
        #    # Get the required Resource
        #    foreach d [${r}::dependencies children] {
        #        set res [$m get_element_by_identifier [$d set identifierref]]
        #        foreach depfile [${res}::files children] {
        #            ${r}::files add $depfile
        #        }
        #    }
        #}

        foreach item [$o all_children_of_type Item] {
            set page [my get_page_for_item $item]
            if {$page ne ""} {
                my msg "Decorating [$page name]  $item "
                $page set page_order [$item set __page_order]
                $page save
            }
        }

      #   foreach item [$o all_children_of_type Item] {
      #       # Get the Resource attached to the Item, if any
      #       if {[$item exists identifierref]} {
      #           set r [$m get_element_by_identifier [$item set identifierref]]
      #           foreach f [${r}::files children] {
      #               my msg "candidate [$f set href] "
      #               # We only attach the page order to the file that has the same href as the resource
      #               if {[$r set href] eq [$f set href]} {
      #                   my msg "decorate: [$f set href] "
      #                   $f set title "[$item title]"
      #                   $f set page_order [$item set page_order]
      #               }
      #               #TODO: Theoretically the href could have spaces (problem with array)"
      #               my set imsfiles([$f set href]) $f
      #               #my log "** preparing file [$f set href] in cp [my set location] for import"
      #           }
      #       }
      #   }
      #   foreach imsfilehref [my array names imsfiles] {
      #       my msg "wanna decorate $imsfilehref"
      #       set page [my resolve_page $imsfilehref view]
      #       if {[[my set imsfiles($imsfilehref)] exists page_order]} {
      #           $page set page_order [[my set imsfiles($imsfilehref)] set page_order]
      #           $page set title [[my set imsfiles($imsfilehref)] set title]
      #       }
      #       $page save
      #   }
    }



    #
    # This is a copy of XoWikis "resolve page" method. We just added the emphasized part
    #

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

    ::ims::cp::Organization instmixin add ::xowiki::ims::cp::Organization

    Organization instproc decorate_page_order {} {
        set prefix ""
        set count 1
        foreach item [my children_of_type Item] {
            $item decorate_page_order $prefix $count
            incr count
        }
    }

    Organization instproc generate_category {-cat_tree_id} {
        set org_cat_id [category::add -tree_id $cat_tree_id -parent_id "" -name "[my title]"]
        foreach item [my children_of_type Item] {
            $item generate_category -cat_tree_id "$cat_tree_id" -parent_id "$org_cat_id"
        }
    }


    Class Item

    ::ims::cp::Item instmixin add ::xowiki::ims::cp::Item

    Item instproc decorate_page_order {prefix count} {
        my set __page_order $prefix$count
        set subcount 1
        foreach item [my children_of_type Item] {
            $item decorate_page_order [my set __page_order]. $subcount
            incr subcount
        }
    }

    Item instproc generate_category {-parent_id -cat_tree_id} {
        my set __item_cat_id [category::add -tree_id $cat_tree_id -parent_id $parent_id -name "[my title]"]
        foreach item [my children_of_type Item] {
            $item generate_category -cat_tree_id "$cat_tree_id" -parent_id "[my set __item_cat_id]"
            my log "$item generate_category -cat_tree_id $cat_tree_id -parent_id [my set __item_cat_id]"

        }
    }






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

            # Resolve dependencies
            foreach d [${r}::dependencies children] {
                # Get the required Resource
                set res [$m get_element_by_identifier [$d set identifierref]]
                foreach depfile [${res}::files children] {
                    my msg "Resolving dependency"
                    ${r}::files add $depfile
                }
            }

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
        #FIXME
        # DEPRECATED

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
::xo::library source_dependent

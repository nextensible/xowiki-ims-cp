::xo::library doc {

    IMS CP Support for XoWiki

    @see http://www.imsglobal.org/content/packaging/
    @creation-date 2009
    @author Michael Aram
}

# TODO: Enforce the suffix .html when pages are created!!! We need that
# TODO: Automatically create xoscorm-index.html page (based on prototype)
# TODO: The  "with_footer" switch of ::xowikiPage-render appends unwanted output
# TODO: Make the frame (stage) resizeable
# TODO: Show Organizations switch only when more then one org 
# TODO: Handle language prefixes. for now, they are just removed. (also file:)
# TODO: Do we want to add .html to all pages?
# TODO: I somehow broke the mime_types: Remove */* 

# FIXME: With "with_user_tracking" parameter set, we get an error when emptying and importing.
# the error comes from "record_last_visited" (but it works anyway)

::xo::library require -absolute t [acs_root_dir]/packages/xowiki/tcl/xowiki-procs
::xo::library require -absolute t [acs_root_dir]/packages/scorm/tcl/scorm-content-packaging-procs

namespace eval ::xowiki::ims {}
namespace eval ::xowiki::ims::cp {

    ::xo::PackageMgr create ::xowiki::ims::cp::Package \
        -package_key "xowiki-ims-cp" \
        -pretty_name "IMS CP Service for XoWiki" \
        -table_name "xowiki_ims_cp" \
        -superclass ::xowiki::Package

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
                ::xo::ConnectionContext require -url [ad_conn url]
                ::xo::cc set_parameter template_file "/packages/xowiki-ims-cp/www/view-sco"
                set f [File create [my autoname exporttmpfile] -temp true ]
                $cri set absolute_links 0
                $f set critem $cri
                $f set content [$cri render -with_footer false]
                $f set mime_type [$cri set mime_type]
                $f set name [regsub "^en:" [$cri set name] ""]
                #$f set_extension_based_on_mimetype
                #my log "[$f serialize]"
                $f save
                lappend files $f
            }
        }

        return $files

    }

    # TODO : This could be done more beatuiful i think!!!
    Package instproc pretty_link args {
        # we need a relative URL
        set package_prefix "[my set package_url]"
        set absolute_internal_url [next]
        set relative_url [regsub $package_prefix $absolute_internal_url ""]
        return $relative_url
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
             if {$name eq "::[[my set xo_pkg_obj] set folder_id]"} {
                 continue
             }
          permission::require_write_permission -object_id $item_id
          ::[my set xo_pkg_obj] delete -item_id $item_id -name $name
        }
    }

    # By default, we import only those items, that are mentioned in the Manifest, which 
    # is correct. Using the switch, we import everything that was in the zippackage.
    ContentPackage instproc import_to_wiki_instance { {-include_dead_files false} } {
        my instvar xo_pkg_obj
        # TODO dirty
        if {$include_dead_files eq false} {
            ns_log notice "LIVE oNLY"
            foreach imsfile [my get_unique_file_objects] {
                #set cp [$imsfile find_content_package]
                set realfile [$imsfile set fileobj]
                $realfile set package_id [$xo_pkg_obj set id]
                $realfile set folder_id  [$xo_pkg_obj set folder_id]
                $realfile mixin add ::xowiki::ims::cp::File
                $realfile to_xowiki
            }
        } else {
            ns_log notice "DEAD TOO"
            foreach realfile [[self]::files children] {
                my log "FILE $realfile ready to import"
                $realfile set package_id [$xo_pkg_obj set id]
                $realfile set folder_id  [$xo_pkg_obj set folder_id]
                $realfile mixin add ::xowiki::ims::cp::File
                $realfile to_xowiki
            }
        }
    }

#    # We extend the XoWiki Objects with the ability to
#    # "write" them as temp_files to disk. Maybe this can be done 
#    # more beautiful
#
#    # this is deprecated
#    Class Page
#    ::xowiki::Page instmixin add ::xowiki::ims::cp::Page
#
#    Page instproc get_cp_filename {} {
#        set filename [my name]
#        #TODO consider MIME and remove language ?
#        regsub -all : $filename _ filename
#        return $filename.html
#    }
#
#    Page instproc write_to_file { {-path "/tmp"} } {
#        set fn "$path/[my get_cp_filename]"
#        set fid [open $fn w]
#        puts $fid [my text]
#        puts $fid [my serialize]
#        close $fid
#        return $fn
#    }

#    Class Resource
#
#    # TODO Do we need dependencies here??
#    Resource instproc import_to_xowiki {} {
#        ds_comment "RESSOURCE: [my serialize]"
#        foreach imsfile [[self]::files children] {
#
#            #we check, whether we already created a file with this url
#
#
#            set cp [$imsfile find_content_package]
#            #ds_comment "CP IS: $cp"
#            set xo_pkg_obj ::[$cp set xo_pkg_obj]
#            #ds_comment "XOCPOBJ IS: $xo_pkg_obj"
#            #ds_comment "XOPKGOBJ: [$xo_pkg_obj serialize]"
#
#
#            #ds_comment "FILE TAG [$imsfile serialize]"
#            set realfile [$imsfile set fileobj]
#            $realfile set package_id [$xo_pkg_obj set id]
#            $realfile set folder_id  [$xo_pkg_obj set folder_id]
#            $realfile mixin add ::xowiki::ims::cp::File
#            #ds_comment "REAL [$realfile serialize]"
#            $realfile to_xowiki
#        }
#    }




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
                        -set title [my set name] \
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


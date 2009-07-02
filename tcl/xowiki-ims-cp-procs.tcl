::xo::library doc {

    IMS CP Support for XoWiki

    @see http://www.imsglobal.org/content/packaging/
    @creation-date 2009
    @author Michael Aram
}

::xo::library require -absolute t [acs_root_dir]/packages/xowiki/tcl/xowiki-procs
::xo::library require -absolute t [acs_root_dir]/packages/ims-cp/tcl/ims-cp-procs
#::xo::library require ../../xowiki/tcl/package-procs


namespace eval ::xowiki::ims {}
namespace eval ::xowiki::ims::cp {

    ::xo::PackageMgr create ::xowiki::ims::cp::Package \
        -package_key "xowiki-ims-cp" \
        -pretty_name "IMS CP Service for XoWiki" \
        -table_name "xowiki_ims_cp" \
        -superclass ::xowiki::Package


    Package ad_instproc export_wiki_as_cp {} {} {
        # Get all Pages
        set pageids [list]
        set sql [::xowiki::Page instance_select_query -with_subtypes 1 -folder_id [my set folder_id] -with_children true]
        db_foreach retrieve_instances $sql {
             # not the folder object 
             if {$name eq "::[my set folder_id]"} {
                 continue
             }
             lappend pageids $item_id
        }

        set files [list]

        foreach item_id $pageids {
            set cri [::xo::db::CrClass get_instance_from_db -item_id $item_id]
            lappend cr_items $cri
            #ds_comment "MISCHA2 [$cri serialize] [$cri info methods]"
            #    ns_log notice "file detected  [acs_root_dir]/content-repository-content-files[$cri set text]"

            if {[file isfile "[acs_root_dir]/content-repository-content-files[$cri set text]"]} {
                set f [::xoutil::File create [my autoname exportfile] -location "[acs_root_dir]/content-repository-content-files[$cri set text]"]
                $f set name [$cri set name]
                lappend files $f
            } else {
                ns_log notice "others detected"
                set f [::xoutil::TempFile create [my autoname exportfile]]
                $f set content [$cri set text]
                $f set name [$cri set name]
                $f save
                lappend files $f
            }
        }


        ContentPackage create cp -location "[acs_root_dir]/packages/ims-cp[ns_tmpnam]"
        cp add_files $files
        set pif [cp pack]
        $pif deliver
    }


    #TODO  Dont make a subclass - make a Service Contract for import
    Class ContentPackage -superclass ::ims::cp::ContentPackage

  #  # This is not beautiful
  #  ContentPackage instproc initpkg {} {
  #      Package initialize
  #      my set xo_pkg_obj $package_id
  #      #ds_comment "CP: [[self] serialize]"
  #      #ds_comment "P: [$package_id serialize]"
  #  }

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


    Class File

    #::xowiki::File instmixin add ::xowiki::ims::cp::File

    File instproc get_cp_filename {} {
        set filename [my name]
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
                        -name [my set name] \
                        -parent_id $folder_id \
                        -package_id $package_id]
                   $f set import_file [my set location]
                   $f save_new
                }
            }
    }
}


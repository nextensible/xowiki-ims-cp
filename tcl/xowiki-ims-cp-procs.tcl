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


    # Todo Dont do a subclass - do a Service Contarct for import

    Class XoWikiPif -superclass ::ims::cp::Package -parameter {
        url
    }

    XoWikiPif instproc init {} {
        next
        my mount_to_site_node
        my import_to_wiki_instance
        ds_comment "[my serialize]"
    }
    

    XoWikiPif instproc mount_to_site_node {} {
        # FIXME

        my set node_name "[my name][clock seconds]"

        my set url "/cps/[my set node_name]"
        set site_node_id [site_node::instantiate_and_mount -package_key xowiki -parent_node_id 3081 -node_name [my set node_name]]
        ds_comment "sitenode: $site_node_id"

        # reeturns null why??
        #my set url [site_node::get_url -node_id $site_node_id]

        ds_comment "URL: [my set url]"
        #my package_id [::xowiki::Package require [my set site_node_id]]
    }



    XoWikiPif instproc import_to_wiki_instance {} {
        ::xowiki::Package initialize -url [my url]
        my set xo_pkg_obj $package_id

        foreach r [[self]::manifest::resources info children] {
            $r mixin Resource
            $r import_to_xowiki
        }
    }


    #::ims::cp::PackageInterchangeFile instmixin add ::xowiki::ims::cp::XoWikiPif

#    Object importer
#
#    importer proc import {} {
#
#
#        ::xowiki::PlainPage create test \
#            -set text {asd} \
#            -set title {sdasd} \
#            -name "NAME" \
#            -parent_id $folder_id \
#            -package_id $package_id
#
#        test save_new
#
#
#
#    }
#
    ################################
    #                              #
    #  ::xowiki::ims::cp::Package  #
    #                              #
    ################################

    Class Package


    

    Package instproc as_ims_cp { } {
        my set filename [my instance_name].zip

        set sql [::xowiki::Page instance_select_query -folder_id [my folder_id] -with_subtypes true]

        set cr_item_ids [db_list get_all_pages $sql]

        my create_from_cr_item_ids -cr_item_ids $cr_item_ids

        my pack_to_pif

    }
   ::xowiki::Package instmixin add ::ims::cp::Package
   ::xowiki::Package instmixin add ::xowiki::ims::cp::Package


 #   Package instproc as_ims_cp {-url} {
 #       ::xowiki::Package initialize -url $url

 #       my set filename [$package_id instance_name].zip

 #       set sql [::xowiki::Page instance_select_query -folder_id [$package_id folder_id] -with_subtypes true]

 #       set cr_item_ids [db_list get_all_pages $sql]

 #       my create_from_cr_item_ids -cr_item_ids $cr_item_ids

 #       my pack_to_pif

 #   }

 #   ::xowiki::ims::cp::Package instmixin add ::ims::cp::Package

    # We extend the XoWiki Objects with the ability to
    # "write" them as temp_files to disk. Maybe this can be done 
    # more beautiful

    Class Page

    Page instproc get_cp_filename {} {
        set filename [my name]
        #TODO consider MIME and remove language ?
        regsub -all : $filename _ filename
        return $filename.html
    }

    Page instproc write_to_file { {-path "/tmp"} } {
        set fn "$path/[my get_cp_filename]"
        set fid [open $fn w]
        puts $fid [my text]
        puts $fid [my serialize]
        close $fid
        return $fn
    }
   
    ::xowiki::Page instmixin add ::xowiki::ims::cp::Page






    Class Resource

    Resource instproc import_to_xowiki {} {
        foreach f [[self]::files info children] {
            $f mixin File
            $f to_xowiki
        }
    }






    Class File


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
        #FIXME

        set package_id [::ims::cp::Factory::pkg set xo_pkg_obj]
        set folder_id [[::ims::cp::Factory::pkg set xo_pkg_obj] folder_id]
            switch -- [my mime_type] {
                "text/html" {
                    ds_comment "HTML: [my serialize]"
                    ::xowiki::Page create o \
                        -set text [list [my set content] [my set mime_type]] \
                        -set title [my set name] \
                        -name [my set name] \
                        -parent_id $folder_id \
                        -package_id $package_id
                o save_new
                }
                "text/plain" {
                    ds_comment "PLAIN: [my serialize]"
                    ::xowiki::PlainPage create o \
                        -set text [list [my set content] [my set mime_type]] \
                        -set title [my set name] \
                        -name [my set name] \
                        -parent_id $folder_id \
                        -package_id $package_id
                o save_new
                }
                default {
                    ds_comment "FILE: [my serialize]"
                    ::xowiki::File create o \
                        -set text [my set content] \
                        -set title [my set set name] \
                        -name [my set name] \
                        -parent_id $folder_id \
                        -package_id $package_id
                }
                o save_new
            }

    }
    ::xowiki::File instmixin add ::xowiki::ims::cp::File


}


::xowiki::ims::cp::Package initialize -ad_doc {
} -parameter {
  {replace 0}
}


set msg ""
ad_form \
    -name upload_form \
    -mode edit \
    -html { enctype multipart/form-data } \
    -form {
      {upload_file:file(file) {html {size 30}} {label "Import file for upload"} }
      {ok_btn:text(submit) {label "[_ acs-templating.HTMLArea_SelectUploadBtn]"} }
    } \
    -on_submit {
      if {$upload_file eq ""} {
          template::form::set_error upload_form upload_file [_ acs-templating.HTMLArea_SpecifyUploadFilename] break 
      }
      # foreach o [::xowiki::Page allinstances] {
      #   set preexists($o) 1
      # }
        ::ims::cp::PackageInterchangeFile create pif -location [template::util::file::get_property tmp_filename $upload_file]

        set pkg [pif unpack]
      #  $pkg mixin add ::xowiki::ims::cp::ContentPackage
      #  $pkg set xo_pkg_obj $package_id
      #  $pkg empty_target_wiki
    } -after_submit {
      #  $pkg import_to_wiki_instance
        set folder_id [$package_id folder_id]
        ::xo::db::CrFolder fetch_object  -item_id $folder_id -object ::cr_folder$folder_id
        ::xoutil::CrImporter new -source $pkg -target ::cr_folder$folder_id

        $package_id decorate_titles
        $package_id decorate_page_order
        $package_id generate_category_organization

        ad_returnredirect "[$package_id package_url]"
    }
set context .

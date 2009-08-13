::template::head::add_css -href "/resources/yui/2.7.0b/build/grids/grids-min.css"
::template::head::add_javascript -order A  -src  "/resources/scorm-rte/prototype.js"
::template::head::add_javascript -order B  -src  "/resources/scorm-rte/scorm_api.js"

::xowiki::ims::cp::Package initialize -url [ad_conn url]
ds_comment [::xo::cc serialize]

set org_id [::xo::cc query_parameter organization_id]
ds_comment "OI: $org_id"

set critem [$package_id get_page_from_name -name "file:imsmanifest.xml"]

if {$critem eq ""} {
    set organization "No manifest found"
} else {
    # TODO - This is dirty here
    # TODO : Import manifest as PlainPage instead of file??
    #::ims::cp::Manifest create manifest -location "[acs_root_dir]/content-repository-content-files/[$manifestobj text]"
    ::ims::cp::Manifest create manifest -cr_item_id "[$critem item_id]"
    if {$org_id eq ""} {
        set org [manifest get_default_or_implicit_organization]
    } else {
        set org [manifest get_organization -identifier $org_id]
    }
    set organization_selector [[manifest::organizations] asXHTML]
    set organization [$org asXHTML]
}

var transformer = require("../transformer");

transformer.register( "moveFirstGoodParagraphUp", function( content ) {
    /*
    Instead of moving the infobox down beneath the first P tag,
    move the first good looking P tag *up* (as the first child of
    the first section div). That way the first P text will appear not
    only above infoboxes, but above other tables/images etc too!
    */

    var edit_section_button_0 = content.querySelector( "#edit_section_button_0" );
    if(!edit_section_button_0) return;

    var p = content.querySelector( '[isFirstGoodParagraph]' );

    if(!p) return;

    function moveAfter(newNode, referenceNode) {
        // Based on: http://stackoverflow.com/a/4793630/135557
        referenceNode.parentNode.insertBefore(newNode.parentNode.removeChild(newNode), referenceNode.nextSibling);
    }

    moveAfter(p, edit_section_button_0);
});

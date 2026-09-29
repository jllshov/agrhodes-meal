// CMS F-Tag / K-Tag reference used to show which tag a failed checklist item
// would most likely be cited under. Titles and regulation citations follow CMS
// State Operations Manual Appendix PP (F-Tags) and Appendix Z/LSC (K-Tags).
// The item → tag mappings live on the checklist definitions in round.html and
// are a starting point — have the compliance lead confirm them for each building.
var FTAGS = {
  F584: { title:'Safe/Clean/Comfortable/Homelike Environment', reg:'§483.10(i)',
          plain:'Rooms and common areas must be clean, sanitary, orderly, well-lit and in good repair.' },
  F585: { title:'Grievances', reg:'§483.10(j)',
          plain:'Resident concerns must be heard, documented, investigated and resolved promptly.' },
  F689: { title:'Free of Accident Hazards/Supervision/Devices', reg:'§483.25(d)',
          plain:'The environment must be as free of accident hazards as possible (beds, clutter, chemicals, wet floors).' },
  F880: { title:'Infection Prevention & Control', reg:'§483.80',
          plain:'Surfaces, equipment and hand-hygiene supplies must support the infection control program.' },
  F908: { title:'Essential Equipment, Safe Operating Condition', reg:'§483.90(d)(2)',
          plain:'Essential resident-care equipment must be maintained in safe operating condition.' },
  F919: { title:'Resident Call System', reg:'§483.90(g)',
          plain:'Each bedside and bathroom must have a working call system the resident can reach.' },
  K920: { title:'Electrical Equipment – Power Cords & Extension Cords', reg:'NFPA 99 / NFPA 70',
          plain:'No daisy-chained power strips or improper extension cords in resident areas.' }
};

function ftagInfo(code) {
  return code ? FTAGS[code] || null : null;
}

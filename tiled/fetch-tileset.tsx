<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.2" name="fetch-tileset" tilewidth="16" tileheight="16" tilecount="400" columns="20">
 <editorsettings>
  <export target="fetch-tileset.lua" format="lua"/>
 </editorsettings>
 <image source="../tiles/fetch-tileset.png" width="320" height="320"/>
 <tile id="0">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="is_water" type="bool" value="true"/>
  </properties>
 </tile>
 <tile id="1" type="npc_reader"/>
 <tile id="2" type="npc_librarian::no_book"/>
 <tile id="3" type="npc_librarian::book"/>
 <tile id="4" type="npc_athlete"/>
 <tile id="5" type="npc_coach"/>
 <tile id="6" type="guard"/>
 <tile id="7" type="npc_jailer"/>
 <tile id="8" type="npc_intro"/>
 <tile id="9" type="npc_child"/>
 <tile id="20" type="blue_duck"/>
 <tile id="21" type="pink_duck"/>
 <tile id="22" type="npc_wizard::no_cap"/>
 <tile id="23" type="npc_wizard::with_hat"/>
 <tile id="24" type="money_bags_duck"/>
 <tile id="25" type="npc_courier"/>
 <tile id="26" type="npc_merchant::no_gift"/>
 <tile id="27" type="npc_merchant::with_gift"/>
 <tile id="28" type="npc_shopkeeper"/>
 <tile id="29" type="chef_duck"/>
 <tile id="30" type="npc_king"/>
 <tile id="31" type="npc_peter::no_tp"/>
 <tile id="32" type="npc_peter::with_tp"/>
 <tile id="33" type="npc_sock_collector::no_sock"/>
 <tile id="34" type="npc_sock_collector::with_sock1"/>
 <tile id="35" type="npc_sock_collector::with_sock2"/>
 <tile id="40" type="farmer_duck"/>
 <tile id="41" type="cartographer_duck"/>
 <tile id="42" type="npc_boat_builder"/>
 <tile id="43" type="npc_lifeguard"/>
 <tile id="44" type="npc_swimmer"/>
 <tile id="45" type="npc_woodcutter"/>
 <tile id="46" type="npc_glitch::glitch1"/>
 <tile id="47" type="npc_glitch::glitch2"/>
 <tile id="48" type="npc_glitch::no_glitch"/>
 <tile id="49" type="plumber_duck"/>
 <tile id="50" type="npc_cat_owner::no_cat"/>
 <tile id="51" type="npc_cat_owner::with_cat"/>
 <tile id="60" type="right_goose"/>
 <tile id="61" type="npc_grey_goose"/>
 <tile id="62" type="npc_white_goose"/>
 <tile id="63" type="npc_canada_goose"/>
 <tile id="100" type="ground::grass"/>
 <tile id="102" type="ground::dirt"/>
 <tile id="104" type="ground::sand"/>
 <tile id="106" type="ground::path"/>
 <tile id="108" type="water">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="-0.1"/>
   <property name="is_water" type="bool" value="true"/>
  </properties>
 </tile>
 <tile id="110" type="ground::clay"/>
 <tile id="112" type="ground::carpet"/>
 <tile id="114" type="ground::stone"/>
 <tile id="128" type="picket::cap_left">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="130" type="picket::cap_right">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="134" type="gravel::bl_corner2"/>
 <tile id="140" type="wall">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="141" type="wall::vines">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="142" type="wall::broken">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="144" type="door"/>
 <tile id="148" type="picket::left_side">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="150" type="picket::right_side">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="152" type="gravel::br_corner"/>
 <tile id="153" type="gravel::cross"/>
 <tile id="154" type="gravel::ew2"/>
 <tile id="155" type="gravel::tr_corner"/>
 <tile id="160" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="161" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="162" type="rock"/>
 <tile id="163" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="164" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.7"/>
  </properties>
 </tile>
 <tile id="165" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="166" type="rock::ice">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="168" type="picket::bl_corner">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="169" type="picket::front">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="170" type="picket::br_corner">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="173" type="gravel::ns"/>
 <tile id="175" type="gravel::ns_2"/>
 <tile id="180" type="tree">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="181" type="decor::mushroom"/>
 <tile id="182" type="decor::grass"/>
 <tile id="183" type="bush">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="193" type="gravel::bl_corner2"/>
 <tile id="194" type="gravel::ew"/>
 <tile id="195" type="gravel::br_corner"/>
 <tile id="200" type="throne">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="201" type="decor::books"/>
 <tile id="240" type="item::cat"/>
 <tile id="241" type="item::book"/>
 <tile id="242" type="item::no_icon"/>
 <tile id="243" type="item::floaties"/>
 <tile id="244" type="item::labubu">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="245" type="item::package"/>
 <tile id="246" type="item::rubber_duck"/>
 <tile id="247" type="item::shoes"/>
 <tile id="248" type="item::wood"/>
 <tile id="250" type="item::wizard_hat"/>
 <tile id="251" type="item::toilet_paper"/>
 <tile id="252" type="item::glitched_item"/>
 <tile id="253" type="item::sock"/>
 <tile id="255" type="item::goose_feathers"/>
 <tile id="271" type="item::toilet_paper_piece"/>
</tileset>

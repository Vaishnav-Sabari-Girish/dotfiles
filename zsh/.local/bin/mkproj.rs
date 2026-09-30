#!/usr/bin/env rust-script
//! ```cargo
//! [dependencies]
//! inquire = "*"
//! ```
use inquire::{Select, Text};
use std::fs::{self, File};
use std::io::Write;
use std::process::{Command, exit};
use std::env;
use std::path::Path;

fn main() {
    println!("🚀 Project Creator");
    let languages = vec![
        "C",
        "Ada",
        "D-simple",
        "Rust",
        "Python",
        "Go",
        "Zig",
        "ESP32-Std",
        "STM32-Embassy",
        "RP2040-HAL",
        "nRF52-Embassy",
        "Zephyr",
        "Arduino",
    ];
    let language = match Select::new("Choose language:", languages)
        .with_page_size(15)
        .prompt()
    {
        Ok(choice) => choice,
        Err(_) => {
            println!("Aborted.");
            exit(0);
        }
    };
    match language {
        "C" => create_c(),
        "Rust" => create_rust(),
        "Python" => create_python(),
        "Go" => create_go(),
        "Zig" => create_zig(),
        "ESP32-Std" => create_esp32_std(),
        "STM32-Embassy" => create_stm32_embassy(),
        "RP2040-HAL" => create_rp2040_hal(),
        "nRF52-Embassy" => create_nrf52_embassy(),
        "Zephyr" => create_zephyr(),
        "Arduino" => create_arduino(),
        "Ada" => create_ada(),
        "D-simple" => create_d_simple(),
        _ => unreachable!(),
    }
    println!("🎉 Happy coding!");
}

fn prompt_project_name() -> String {
    Text::new("Enter project name:")
        .prompt()
        .unwrap_or_else(|_| {
            println!("Aborted.");
            exit(0);
        })
}

fn create_dir_and_cd(name: &str) {
    fs::create_dir_all(name).expect("Failed to create project directory");
    env::set_current_dir(name).expect("Failed to change directory");
}

fn write_file(path: &str, content: &str) {
    let mut file = File::create(path).expect(&format!("Failed to create {}", path));
    file.write_all(content.as_bytes())
        .expect(&format!("Failed to write {}", path));
}

// ==================== C ====================
fn create_c() {
    println!("📁 Creating C project...");
    let variants = vec!["Simple project", "Complex project (CMake + clang tools)"];
    let variant = match Select::new("Choose C project type:", variants)
        .with_page_size(5)
        .prompt()
    {
        Ok(choice) => choice,
        Err(_) => {
            println!("Aborted.");
            exit(0);
        }
    };

    match variant {
        "Simple project" => create_c_simple(),
        "Complex project (CMake + clang tools)" => create_c_complex(),
        _ => unreachable!(),
    }
}

fn create_c_simple() {
    let project_name = prompt_project_name();
    create_dir_and_cd(&project_name);
    write_file(
        "main.c",
        r#"#include <stdio.h>
int main() {
  printf("Hello, World!\n");
  return 0;
}
"#,
    );
    write_file(
        "Grimoire.toml",
        r#"version = "1"
[ingredients]
c_compiler = "gcc"
cflags = "-Wall -Wextra -O2"
src = "main.c"
out = "main.out"
[sigil.build]
description = "Build the C project"
language = "shell"
silent = true
run = "{{c_compiler}} {{src}} -o {{out}} {{cflags}}"
[sigil.run]
description = "Run the binary"
language = "shell"
silent = true
run = "./{{out}}"
[sigil.br]
description = "Build + Run + Clean"
language = "shell"
silent = true
run = '''
{{c_compiler}} {{src}} -o {{out}} {{cflags}}
./{{out}}
rm -f {{out}}
'''
[sigil.clean]
description = "Remove the binary"
language = "shell"
silent = true
run = "rm -f {{out}}"
"#,
    );
    println!("✅ Simple C project '{}' created!", project_name);
}

fn create_c_complex() {
    let project_name = prompt_project_name();
    create_dir_and_cd(&project_name);

    // main.c
    write_file(
        "main.c",
        r#"#include <stdio.h>

int main(void)
{
    printf("Hello, World!\n");
    return 0;
}
"#,
    );

    // CMakeLists.txt
    write_file(
        "CMakeLists.txt",
        &format!(
            r#"cmake_minimum_required(VERSION 3.16)

project({} C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(${{PROJECT_NAME}} main.c)

# Optional: install target
# install(TARGETS ${{PROJECT_NAME}} DESTINATION bin)
"#,
            project_name
        ),
    );

    // .clang-format
    write_file(
        ".clang-format",
        r#"# SPDX-License-Identifier: GPL-2.0
#
# clang-format configuration file. Intended for clang-format >= 11.
#
# For more information, see:
#
#   Documentation/dev-tools/clang-format.rst
#   https://clang.llvm.org/docs/ClangFormat.html
#   https://clang.llvm.org/docs/ClangFormatStyleOptions.html
#
---
AccessModifierOffset: -4
AlignAfterOpenBracket: BlockIndent
AlignConsecutiveAssignments: false
AlignConsecutiveDeclarations: false
AlignEscapedNewlines: Left
AlignOperands: true
AlignTrailingComments: false
AllowAllParametersOfDeclarationOnNextLine: false
AllowShortBlocksOnASingleLine: false
AllowShortCaseLabelsOnASingleLine: false
AllowShortFunctionsOnASingleLine: None
AllowShortIfStatementsOnASingleLine: false
AllowShortLoopsOnASingleLine: false
AlwaysBreakAfterDefinitionReturnType: None
AlwaysBreakAfterReturnType: None
AlwaysBreakBeforeMultilineStrings: false
AlwaysBreakTemplateDeclarations: false
BinPackArguments: false
BinPackParameters: false
BraceWrapping:
  AfterClass: false
  AfterControlStatement: false
  AfterEnum: false
  AfterFunction: true
  AfterNamespace: true
  AfterObjCDeclaration: false
  AfterStruct: false
  AfterUnion: false
  AfterExternBlock: false
  BeforeCatch: false
  BeforeElse: false
  IndentBraces: false
  SplitEmptyFunction: true
  SplitEmptyRecord: true
  SplitEmptyNamespace: true
BreakBeforeBinaryOperators: None
BreakBeforeBraces: Custom
BreakBeforeInheritanceComma: false
BreakBeforeTernaryOperators: false
BreakConstructorInitializersBeforeComma: false
BreakConstructorInitializers: BeforeComma
BreakAfterJavaFieldAnnotations: false
BreakStringLiterals: false
ColumnLimit: 120
CommentPragmas: '^ IWYU pragma:'
CompactNamespaces: false
ConstructorInitializerAllOnOneLineOrOnePerLine: false
ConstructorInitializerIndentWidth: 4
ContinuationIndentWidth: 4
Cpp11BracedListStyle: false
DerivePointerAlignment: false
DisableFormat: false
ExperimentalAutoDetectBinPacking: false
FixNamespaceComments: false
# Taken from:
#   git grep -h '^#define [^[:space:]]*for_each[^[:space:]]*(' include/ tools/ \
#   | sed "s,^#define \([^[:space:]]*for_each[^[:space:]]*\)(.*$,  - '\1'," \
#   | LC_ALL=C sort -u
ForEachMacros:
  - '__ata_qc_for_each'
  - '__bio_for_each_bvec'
  - '__bio_for_each_segment'
  - '__evlist__for_each_entry'
  - '__evlist__for_each_entry_continue'
  - '__evlist__for_each_entry_from'
  - '__evlist__for_each_entry_reverse'
  - '__evlist__for_each_entry_safe'
  - '__for_each_mem_range'
  - '__for_each_mem_range_rev'
  - '__for_each_thread'
  - '__hlist_for_each_rcu'
  - '__map__for_each_symbol_by_name'
  - '__pci_bus_for_each_res0'
  - '__pci_bus_for_each_res1'
  - '__pci_dev_for_each_res0'
  - '__pci_dev_for_each_res1'
  - '__perf_evlist__for_each_entry'
  - '__perf_evlist__for_each_entry_reverse'
  - '__perf_evlist__for_each_entry_safe'
  - '__rq_for_each_bio'
  - '__shost_for_each_device'
  - '__sym_for_each'
  - '_for_each_counter'
  - 'apei_estatus_for_each_section'
  - 'ata_for_each_dev'
  - 'ata_for_each_link'
  - 'ata_qc_for_each'
  - 'ata_qc_for_each_raw'
  - 'ata_qc_for_each_with_internal'
  - 'ax25_for_each'
  - 'ax25_uid_for_each'
  - 'bio_for_each_bvec'
  - 'bio_for_each_bvec_all'
  - 'bio_for_each_folio_all'
  - 'bio_for_each_integrity_vec'
  - 'bio_for_each_segment'
  - 'bio_for_each_segment_all'
  - 'bio_list_for_each'
  - 'bip_for_each_vec'
  - 'bond_for_each_slave'
  - 'bond_for_each_slave_rcu'
  - 'bpf_for_each'
  - 'bpf_for_each_reg_in_vstate'
  - 'bpf_for_each_reg_in_vstate_mask'
  - 'bpf_for_each_spilled_reg'
  - 'bpf_object__for_each_map'
  - 'bpf_object__for_each_program'
  - 'btree_for_each_safe128'
  - 'btree_for_each_safe32'
  - 'btree_for_each_safe64'
  - 'btree_for_each_safel'
  - 'card_for_each_dev'
  - 'cgroup_taskset_for_each'
  - 'cgroup_taskset_for_each_leader'
  - 'cpu_aggr_map__for_each_idx'
  - 'cpufreq_for_each_efficient_entry_idx'
  - 'cpufreq_for_each_entry'
  - 'cpufreq_for_each_entry_idx'
  - 'cpufreq_for_each_valid_entry'
  - 'cpufreq_for_each_valid_entry_idx'
  - 'css_for_each_child'
  - 'css_for_each_descendant_post'
  - 'css_for_each_descendant_pre'
  - 'damon_for_each_region'
  - 'damon_for_each_region_from'
  - 'damon_for_each_region_safe'
  - 'damon_for_each_scheme'
  - 'damon_for_each_scheme_safe'
  - 'damon_for_each_target'
  - 'damon_for_each_target_safe'
  - 'damos_for_each_core_filter'
  - 'damos_for_each_core_filter_safe'
  - 'damos_for_each_ops_filter'
  - 'damos_for_each_ops_filter_safe'
  - 'damos_for_each_quota_goal'
  - 'damos_for_each_quota_goal_safe'
  - 'data__for_each_file'
  - 'data__for_each_file_new'
  - 'data__for_each_file_start'
  - 'def_for_each_cpu'
  - 'device_for_each_child_node'
  - 'device_for_each_child_node_scoped'
  - 'dma_fence_array_for_each'
  - 'dma_fence_chain_for_each'
  - 'dma_fence_unwrap_for_each'
  - 'dma_resv_for_each_fence'
  - 'dma_resv_for_each_fence_unlocked'
  - 'do_for_each_ftrace_op'
  - 'drm_atomic_crtc_for_each_plane'
  - 'drm_atomic_crtc_state_for_each_plane'
  - 'drm_atomic_crtc_state_for_each_plane_state'
  - 'drm_atomic_for_each_plane_damage'
  - 'drm_client_for_each_connector_iter'
  - 'drm_client_for_each_modeset'
  - 'drm_connector_for_each_possible_encoder'
  - 'drm_exec_for_each_locked_object'
  - 'drm_exec_for_each_locked_object_reverse'
  - 'drm_for_each_bridge_in_chain_scoped'
  - 'drm_for_each_connector_iter'
  - 'drm_for_each_crtc'
  - 'drm_for_each_crtc_reverse'
  - 'drm_for_each_encoder'
  - 'drm_for_each_encoder_mask'
  - 'drm_for_each_fb'
  - 'drm_for_each_legacy_plane'
  - 'drm_for_each_plane'
  - 'drm_for_each_plane_mask'
  - 'drm_for_each_privobj'
  - 'drm_gem_for_each_gpuvm_bo'
  - 'drm_gem_for_each_gpuvm_bo_safe'
  - 'drm_gpusvm_for_each_range'
  - 'drm_gpuva_for_each_op'
  - 'drm_gpuva_for_each_op_from_reverse'
  - 'drm_gpuva_for_each_op_reverse'
  - 'drm_gpuva_for_each_op_safe'
  - 'drm_gpuvm_bo_for_each_va'
  - 'drm_gpuvm_bo_for_each_va_safe'
  - 'drm_gpuvm_for_each_va'
  - 'drm_gpuvm_for_each_va_range'
  - 'drm_gpuvm_for_each_va_range_safe'
  - 'drm_gpuvm_for_each_va_safe'
  - 'drm_mm_for_each_hole'
  - 'drm_mm_for_each_node'
  - 'drm_mm_for_each_node_in_range'
  - 'drm_mm_for_each_node_safe'
  - 'dsa_switch_for_each_available_port'
  - 'dsa_switch_for_each_cpu_port'
  - 'dsa_switch_for_each_cpu_port_continue_reverse'
  - 'dsa_switch_for_each_port'
  - 'dsa_switch_for_each_port_continue_reverse'
  - 'dsa_switch_for_each_port_safe'
  - 'dsa_switch_for_each_user_port'
  - 'dsa_switch_for_each_user_port_continue_reverse'
  - 'dsa_tree_for_each_cpu_port'
  - 'dsa_tree_for_each_user_port'
  - 'dsa_tree_for_each_user_port_continue_reverse'
  - 'dso__for_each_symbol'
  - 'elf_hash_for_each_possible'
  - 'elf_symtab__for_each_symbol'
  - 'evlist__for_each_cpu'
  - 'evlist__for_each_entry'
  - 'evlist__for_each_entry_continue'
  - 'evlist__for_each_entry_from'
  - 'evlist__for_each_entry_reverse'
  - 'evlist__for_each_entry_safe'
  - 'flow_action_for_each'
  - 'for_each_acpi_consumer_dev'
  - 'for_each_acpi_dev_match'
  - 'for_each_active_dev_scope'
  - 'for_each_active_drhd_unit'
  - 'for_each_active_iommu'
  - 'for_each_active_irq'
  - 'for_each_active_route'
  - 'for_each_aggr_pgid'
  - 'for_each_alloc_capable_rdt_resource'
  - 'for_each_and_bit'
  - 'for_each_andnot_bit'
  - 'for_each_available_child_of_node'
  - 'for_each_available_child_of_node_scoped'
  - 'for_each_bench'
  - 'for_each_bio'
  - 'for_each_board_func_rsrc'
  - 'for_each_btf_ext_rec'
  - 'for_each_btf_ext_sec'
  - 'for_each_bvec'
  - 'for_each_capable_rdt_resource'
  - 'for_each_card_auxs'
  - 'for_each_card_auxs_safe'
  - 'for_each_card_components'
  - 'for_each_card_dapms'
  - 'for_each_card_pre_auxs'
  - 'for_each_card_prelinks'
  - 'for_each_card_rtds'
  - 'for_each_card_rtds_safe'
  - 'for_each_card_widgets'
  - 'for_each_card_widgets_safe'
  - 'for_each_cgroup_storage_type'
  - 'for_each_child_of_node'
  - 'for_each_child_of_node_scoped'
  - 'for_each_child_of_node_with_prefix'
  - 'for_each_clear_bit'
  - 'for_each_clear_bit_from'
  - 'for_each_clear_bitrange'
  - 'for_each_clear_bitrange_from'
  - 'for_each_cmd'
  - 'for_each_cmsghdr'
  - 'for_each_collection'
  - 'for_each_comp_order'
  - 'for_each_compatible_node'
  - 'for_each_compatible_node_scoped'
  - 'for_each_component_dais'
  - 'for_each_component_dais_safe'
  - 'for_each_conduit'
  - 'for_each_console'
  - 'for_each_console_srcu'
  - 'for_each_cpu'
  - 'for_each_cpu_and'
  - 'for_each_cpu_andnot'
  - 'for_each_cpu_from'
  - 'for_each_cpu_or'
  - 'for_each_cpu_wrap'
  - 'for_each_dapm_widgets'
  - 'for_each_dedup_cand'
  - 'for_each_dev_addr'
  - 'for_each_dev_scope'
  - 'for_each_dma_cap_mask'
  - 'for_each_dpcm_be'
  - 'for_each_dpcm_be_rollback'
  - 'for_each_dpcm_be_safe'
  - 'for_each_dpcm_fe'
  - 'for_each_drhd_unit'
  - 'for_each_dss_dev'
  - 'for_each_efi_memory_desc'
  - 'for_each_efi_memory_desc_in_map'
  - 'for_each_element'
  - 'for_each_element_extid'
  - 'for_each_element_id'
  - 'for_each_enabled_cpu'
  - 'for_each_endpoint_of_node'
  - 'for_each_event'
  - 'for_each_event_tps'
  - 'for_each_evictable_lru'
  - 'for_each_fib6_node_rt_rcu'
  - 'for_each_fib6_walker_rt'
  - 'for_each_file_lock'
  - 'for_each_free_mem_range'
  - 'for_each_free_mem_range_reverse'
  - 'for_each_func_rsrc'
  - 'for_each_gpiochip_node'
  - 'for_each_group_evsel'
  - 'for_each_group_evsel_head'
  - 'for_each_group_member'
  - 'for_each_group_member_head'
  - 'for_each_hstate'
  - 'for_each_hwgpio'
  - 'for_each_hwgpio_in_range'
  - 'for_each_if'
  - 'for_each_inject_fn'
  - 'for_each_insn'
  - 'for_each_insn_op_loc'
  - 'for_each_insn_prefix'
  - 'for_each_intid'
  - 'for_each_iommu'
  - 'for_each_ip_tunnel_rcu'
  - 'for_each_irq_desc'
  - 'for_each_irq_nr'
  - 'for_each_lang'
  - 'for_each_link_ch_maps'
  - 'for_each_link_codecs'
  - 'for_each_link_cpus'
  - 'for_each_link_platforms'
  - 'for_each_lru'
  - 'for_each_matching_node'
  - 'for_each_matching_node_and_match'
  - 'for_each_media_entity_data_link'
  - 'for_each_mem_pfn_range'
  - 'for_each_mem_range'
  - 'for_each_mem_range_rev'
  - 'for_each_mem_region'
  - 'for_each_member'
  - 'for_each_memory'
  - 'for_each_migratetype_order'
  - 'for_each_missing_reg'
  - 'for_each_mle_subelement'
  - 'for_each_mod_mem_type'
  - 'for_each_mon_capable_rdt_resource'
  - 'for_each_mp_bvec'
  - 'for_each_net'
  - 'for_each_net_continue_reverse'
  - 'for_each_net_rcu'
  - 'for_each_netdev'
  - 'for_each_netdev_continue'
  - 'for_each_netdev_continue_rcu'
  - 'for_each_netdev_continue_reverse'
  - 'for_each_netdev_dump'
  - 'for_each_netdev_feature'
  - 'for_each_netdev_in_bond_rcu'
  - 'for_each_netdev_rcu'
  - 'for_each_netdev_reverse'
  - 'for_each_netdev_safe'
  - 'for_each_new_connector_in_state'
  - 'for_each_new_crtc_in_state'
  - 'for_each_new_mst_mgr_in_state'
  - 'for_each_new_plane_in_state'
  - 'for_each_new_plane_in_state_reverse'
  - 'for_each_new_private_obj_in_state'
  - 'for_each_new_reg'
  - 'for_each_nhlt_endpoint'
  - 'for_each_nhlt_endpoint_fmtcfg'
  - 'for_each_nhlt_fmtcfg'
  - 'for_each_node'
  - 'for_each_node_by_name'
  - 'for_each_node_by_type'
  - 'for_each_node_mask'
  - 'for_each_node_numadist'
  - 'for_each_node_state'
  - 'for_each_node_with_cpus'
  - 'for_each_node_with_property'
  - 'for_each_nonreserved_multicast_dest_pgid'
  - 'for_each_numa_hop_mask'
  - 'for_each_of_allnodes'
  - 'for_each_of_allnodes_from'
  - 'for_each_of_cpu_node'
  - 'for_each_of_graph_port'
  - 'for_each_of_graph_port_endpoint'
  - 'for_each_of_pci_range'
  - 'for_each_old_connector_in_state'
  - 'for_each_old_crtc_in_state'
  - 'for_each_old_mst_mgr_in_state'
  - 'for_each_old_plane_in_state'
  - 'for_each_old_private_obj_in_state'
  - 'for_each_oldnew_connector_in_state'
  - 'for_each_oldnew_crtc_in_state'
  - 'for_each_oldnew_mst_mgr_in_state'
  - 'for_each_oldnew_plane_in_state'
  - 'for_each_oldnew_plane_in_state_reverse'
  - 'for_each_oldnew_private_obj_in_state'
  - 'for_each_online_cpu'
  - 'for_each_online_cpu_wrap'
  - 'for_each_online_node'
  - 'for_each_online_pgdat'
  - 'for_each_or_bit'
  - 'for_each_page_ext'
  - 'for_each_path'
  - 'for_each_pci_bridge'
  - 'for_each_pci_dev'
  - 'for_each_pcm_streams'
  - 'for_each_physmem_range'
  - 'for_each_populated_zone'
  - 'for_each_possible_cpu'
  - 'for_each_possible_cpu_wrap'
  - 'for_each_present_blessed_reg'
  - 'for_each_present_cpu'
  - 'for_each_present_section_nr'
  - 'for_each_prime_number'
  - 'for_each_prime_number_from'
  - 'for_each_probe_cache_entry'
  - 'for_each_process'
  - 'for_each_process_thread'
  - 'for_each_prop_codec_conf'
  - 'for_each_prop_dai_codec'
  - 'for_each_prop_dai_cpu'
  - 'for_each_prop_dlc_codecs'
  - 'for_each_prop_dlc_cpus'
  - 'for_each_prop_dlc_platforms'
  - 'for_each_property_of_node'
  - 'for_each_pt_level_entry'
  - 'for_each_rdt_resource'
  - 'for_each_reg'
  - 'for_each_reg_filtered'
  - 'for_each_reloc'
  - 'for_each_reloc_from'
  - 'for_each_requested_gpio'
  - 'for_each_requested_gpio_in_range'
  - 'for_each_reserved_child_of_node'
  - 'for_each_reserved_mem_range'
  - 'for_each_reserved_mem_region'
  - 'for_each_rtd_ch_maps'
  - 'for_each_rtd_codec_dais'
  - 'for_each_rtd_components'
  - 'for_each_rtd_cpu_dais'
  - 'for_each_rtd_dais'
  - 'for_each_rtd_dais_reverse'
  - 'for_each_sband_iftype_data'
  - 'for_each_script'
  - 'for_each_sec'
  - 'for_each_set_bit'
  - 'for_each_set_bit_from'
  - 'for_each_set_bit_wrap'
  - 'for_each_set_bitrange'
  - 'for_each_set_bitrange_from'
  - 'for_each_set_clump8'
  - 'for_each_sg'
  - 'for_each_sg_dma_page'
  - 'for_each_sg_page'
  - 'for_each_sgtable_dma_page'
  - 'for_each_sgtable_dma_sg'
  - 'for_each_sgtable_page'
  - 'for_each_sgtable_sg'
  - 'for_each_sibling_event'
  - 'for_each_sta_active_link'
  - 'for_each_subelement'
  - 'for_each_subelement_extid'
  - 'for_each_subelement_id'
  - 'for_each_sublist'
  - 'for_each_subsystem'
  - 'for_each_suite'
  - 'for_each_supported_activate_fn'
  - 'for_each_supported_inject_fn'
  - 'for_each_sym'
  - 'for_each_thread'
  - 'for_each_token'
  - 'for_each_unicast_dest_pgid'
  - 'for_each_valid_link'
  - 'for_each_vif_active_link'
  - 'for_each_vma'
  - 'for_each_vma_range'
  - 'for_each_vsi'
  - 'for_each_wakeup_source'
  - 'for_each_zone'
  - 'for_each_zone_zonelist'
  - 'for_each_zone_zonelist_nodemask'
  - 'func_for_each_insn'
  - 'fwnode_for_each_available_child_node'
  - 'fwnode_for_each_child_node'
  - 'fwnode_for_each_parent_node'
  - 'fwnode_graph_for_each_endpoint'
  - 'gadget_for_each_ep'
  - 'genradix_for_each'
  - 'genradix_for_each_from'
  - 'genradix_for_each_reverse'
  - 'guard'
  - 'hash_for_each'
  - 'hash_for_each_possible'
  - 'hash_for_each_possible_rcu'
  - 'hash_for_each_possible_rcu_notrace'
  - 'hash_for_each_possible_safe'
  - 'hash_for_each_rcu'
  - 'hash_for_each_safe'
  - 'hashmap__for_each_entry'
  - 'hashmap__for_each_entry_safe'
  - 'hashmap__for_each_key_entry'
  - 'hashmap__for_each_key_entry_safe'
  - 'hctx_for_each_ctx'
  - 'hists__for_each_format'
  - 'hists__for_each_sort_list'
  - 'hlist_bl_for_each_entry'
  - 'hlist_bl_for_each_entry_rcu'
  - 'hlist_bl_for_each_entry_safe'
  - 'hlist_for_each'
  - 'hlist_for_each_entry'
  - 'hlist_for_each_entry_continue'
  - 'hlist_for_each_entry_continue_rcu'
  - 'hlist_for_each_entry_continue_rcu_bh'
  - 'hlist_for_each_entry_from'
  - 'hlist_for_each_entry_from_rcu'
  - 'hlist_for_each_entry_rcu'
  - 'hlist_for_each_entry_rcu_bh'
  - 'hlist_for_each_entry_rcu_notrace'
  - 'hlist_for_each_entry_safe'
  - 'hlist_for_each_entry_srcu'
  - 'hlist_for_each_safe'
  - 'hlist_nulls_for_each_entry'
  - 'hlist_nulls_for_each_entry_from'
  - 'hlist_nulls_for_each_entry_rcu'
  - 'hlist_nulls_for_each_entry_safe'
  - 'i3c_bus_for_each_i2cdev'
  - 'i3c_bus_for_each_i3cdev'
  - 'idr_for_each_entry'
  - 'idr_for_each_entry_continue'
  - 'idr_for_each_entry_continue_ul'
  - 'idr_for_each_entry_ul'
  - 'iio_for_each_active_channel'
  - 'in_dev_for_each_ifa_rcu'
  - 'in_dev_for_each_ifa_rtnl'
  - 'in_dev_for_each_ifa_rtnl_net'
  - 'inet_bind_bucket_for_each'
  - 'interval_tree_for_each_span'
  - 'intlist__for_each_entry'
  - 'intlist__for_each_entry_safe'
  - 'kcore_copy__for_each_phdr'
  - 'key_for_each'
  - 'key_for_each_safe'
  - 'klp_for_each_func'
  - 'klp_for_each_func_safe'
  - 'klp_for_each_func_static'
  - 'klp_for_each_object'
  - 'klp_for_each_object_safe'
  - 'klp_for_each_object_static'
  - 'kunit_suite_for_each_test_case'
  - 'kvm_for_each_memslot'
  - 'kvm_for_each_memslot_in_gfn_range'
  - 'kvm_for_each_vcpu'
  - 'libbpf_nla_for_each_attr'
  - 'list_for_each'
  - 'list_for_each_codec'
  - 'list_for_each_codec_safe'
  - 'list_for_each_continue'
  - 'list_for_each_entry'
  - 'list_for_each_entry_continue'
  - 'list_for_each_entry_continue_rcu'
  - 'list_for_each_entry_continue_reverse'
  - 'list_for_each_entry_from'
  - 'list_for_each_entry_from_rcu'
  - 'list_for_each_entry_from_reverse'
  - 'list_for_each_entry_lockless'
  - 'list_for_each_entry_rcu'
  - 'list_for_each_entry_reverse'
  - 'list_for_each_entry_safe'
  - 'list_for_each_entry_safe_continue'
  - 'list_for_each_entry_safe_from'
  - 'list_for_each_entry_safe_reverse'
  - 'list_for_each_entry_srcu'
  - 'list_for_each_from'
  - 'list_for_each_prev'
  - 'list_for_each_prev_safe'
  - 'list_for_each_rcu'
  - 'list_for_each_safe'
  - 'llist_for_each'
  - 'llist_for_each_entry'
  - 'llist_for_each_entry_safe'
  - 'llist_for_each_safe'
  - 'lwq_for_each_safe'
  - 'map__for_each_symbol'
  - 'map__for_each_symbol_by_name'
  - 'mas_for_each'
  - 'mas_for_each_rev'
  - 'mci_for_each_dimm'
  - 'media_device_for_each_entity'
  - 'media_device_for_each_intf'
  - 'media_device_for_each_link'
  - 'media_device_for_each_pad'
  - 'media_entity_for_each_pad'
  - 'media_pipeline_for_each_entity'
  - 'media_pipeline_for_each_pad'
  - 'mlx5_lag_for_each_peer_mdev'
  - 'mptcp_for_each_subflow'
  - 'msi_domain_for_each_desc'
  - 'msi_for_each_desc'
  - 'mt_for_each'
  - 'nanddev_io_for_each_block'
  - 'nanddev_io_for_each_page'
  - 'neigh_for_each_in_bucket'
  - 'neigh_for_each_in_bucket_rcu'
  - 'neigh_for_each_in_bucket_safe'
  - 'netdev_for_each_lower_dev'
  - 'netdev_for_each_lower_private'
  - 'netdev_for_each_lower_private_rcu'
  - 'netdev_for_each_mc_addr'
  - 'netdev_for_each_synced_mc_addr'
  - 'netdev_for_each_synced_uc_addr'
  - 'netdev_for_each_uc_addr'
  - 'netdev_for_each_upper_dev_rcu'
  - 'netdev_hw_addr_list_for_each'
  - 'nft_rule_for_each_expr'
  - 'nla_for_each_attr'
  - 'nla_for_each_attr_type'
  - 'nla_for_each_nested'
  - 'nla_for_each_nested_type'
  - 'nlmsg_for_each_attr'
  - 'nlmsg_for_each_msg'
  - 'nr_neigh_for_each'
  - 'nr_neigh_for_each_safe'
  - 'nr_node_for_each'
  - 'nr_node_for_each_safe'
  - 'of_for_each_phandle'
  - 'of_property_for_each_string'
  - 'of_property_for_each_u32'
  - 'pci_bus_for_each_resource'
  - 'pci_dev_for_each_resource'
  - 'pcl_for_each_chunk'
  - 'pcl_for_each_segment'
  - 'pcm_for_each_format'
  - 'perf_config_items__for_each_entry'
  - 'perf_config_sections__for_each_entry'
  - 'perf_config_set__for_each_entry'
  - 'perf_cpu_map__for_each_cpu'
  - 'perf_cpu_map__for_each_cpu_skip_any'
  - 'perf_cpu_map__for_each_idx'
  - 'perf_evlist__for_each_entry'
  - 'perf_evlist__for_each_entry_reverse'
  - 'perf_evlist__for_each_entry_safe'
  - 'perf_evlist__for_each_evsel'
  - 'perf_evlist__for_each_mmap'
  - 'perf_evsel_for_each_per_thread_period_safe'
  - 'perf_hpp_list__for_each_format'
  - 'perf_hpp_list__for_each_format_safe'
  - 'perf_hpp_list__for_each_sort_list'
  - 'perf_hpp_list__for_each_sort_list_safe'
  - 'plist_for_each'
  - 'plist_for_each_continue'
  - 'plist_for_each_entry'
  - 'plist_for_each_entry_continue'
  - 'plist_for_each_entry_safe'
  - 'plist_for_each_safe'
  - 'pnp_for_each_card'
  - 'pnp_for_each_dev'
  - 'protocol_for_each_card'
  - 'protocol_for_each_dev'
  - 'queue_for_each_hw_ctx'
  - 'radix_tree_for_each_slot'
  - 'radix_tree_for_each_tagged'
  - 'rb_for_each'
  - 'rbtree_postorder_for_each_entry_safe'
  - 'rdma_for_each_block'
  - 'rdma_for_each_port'
  - 'rdma_umem_for_each_dma_block'
  - 'resource_list_for_each_entry'
  - 'resource_list_for_each_entry_safe'
  - 'rhl_for_each_entry_rcu'
  - 'rhl_for_each_rcu'
  - 'rht_for_each'
  - 'rht_for_each_entry'
  - 'rht_for_each_entry_from'
  - 'rht_for_each_entry_rcu'
  - 'rht_for_each_entry_rcu_from'
  - 'rht_for_each_entry_safe'
  - 'rht_for_each_from'
  - 'rht_for_each_rcu'
  - 'rht_for_each_rcu_from'
  - 'rq_for_each_bvec'
  - 'rq_for_each_segment'
  - 'rq_list_for_each'
  - 'rq_list_for_each_safe'
  - 'sample_read_group__for_each'
  - 'scoped_guard'
  - 'scsi_for_each_prot_sg'
  - 'scsi_for_each_sg'
  - 'sctp_for_each_hentry'
  - 'sctp_skb_for_each'
  - 'sec_for_each_insn'
  - 'sec_for_each_insn_continue'
  - 'sec_for_each_insn_from'
  - 'sec_for_each_sym'
  - 'shdma_for_each_chan'
  - 'shost_for_each_device'
  - 'sk_for_each'
  - 'sk_for_each_bound'
  - 'sk_for_each_bound_safe'
  - 'sk_for_each_entry_offset_rcu'
  - 'sk_for_each_from'
  - 'sk_for_each_rcu'
  - 'sk_for_each_safe'
  - 'sk_nulls_for_each'
  - 'sk_nulls_for_each_from'
  - 'sk_nulls_for_each_rcu'
  - 'snd_array_for_each'
  - 'snd_pcm_group_for_each_entry'
  - 'snd_soc_dapm_widget_for_each_path'
  - 'snd_soc_dapm_widget_for_each_path_safe'
  - 'snd_soc_dapm_widget_for_each_sink_path'
  - 'snd_soc_dapm_widget_for_each_source_path'
  - 'sparsebit_for_each_set_range'
  - 'strlist__for_each_entry'
  - 'strlist__for_each_entry_safe'
  - 'sym_for_each_insn'
  - 'sym_for_each_insn_continue_reverse'
  - 'symbols__for_each_entry'
  - 'tb_property_for_each'
  - 'tcf_act_for_each_action'
  - 'tcf_exts_for_each_action'
  - 'test_suite__for_each_test_case'
  - 'tool_pmu__for_each_event'
  - 'ttm_bo_lru_for_each_reserved_guarded'
  - 'ttm_resource_manager_for_each_res'
  - 'udp_lrpa_for_each_entry_rcu'
  - 'udp_portaddr_for_each_entry'
  - 'udp_portaddr_for_each_entry_rcu'
  - 'usb_hub_for_each_child'
  - 'v4l2_device_for_each_subdev'
  - 'v4l2_m2m_for_each_dst_buf'
  - 'v4l2_m2m_for_each_dst_buf_safe'
  - 'v4l2_m2m_for_each_src_buf'
  - 'v4l2_m2m_for_each_src_buf_safe'
  - 'virtio_device_for_each_vq'
  - 'vkms_config_for_each_connector'
  - 'vkms_config_for_each_crtc'
  - 'vkms_config_for_each_encoder'
  - 'vkms_config_for_each_plane'
  - 'vkms_config_connector_for_each_possible_encoder'
  - 'vkms_config_encoder_for_each_possible_crtc'
  - 'vkms_config_plane_for_each_possible_crtc'
  - 'while_for_each_ftrace_op'
  - 'workloads__for_each'
  - 'xa_for_each'
  - 'xa_for_each_marked'
  - 'xa_for_each_range'
  - 'xa_for_each_start'
  - 'xas_for_each'
  - 'xas_for_each_conflict'
  - 'xas_for_each_marked'
  - 'xbc_array_for_each_value'
  - 'xbc_for_each_key_value'
  - 'xbc_node_for_each_array_value'
  - 'xbc_node_for_each_child'
  - 'xbc_node_for_each_key_value'
  - 'xbc_node_for_each_subkey'
  - 'ynl_attr_for_each'
  - 'ynl_attr_for_each_nested'
  - 'ynl_attr_for_each_payload'
  - 'zorro_for_each_dev'
  - 'zpci_bus_for_each'
IncludeBlocks: Preserve
IncludeCategories:
  - Regex: '.*'
    Priority: 1
IncludeIsMainRegex: '(Test)?$'
IndentCaseLabels: false
IndentGotoLabels: false
IndentPPDirectives: None
IndentWidth: 4
IndentWrappedFunctionNames: false
JavaScriptQuotes: Leave
JavaScriptWrapImports: true
KeepEmptyLinesAtTheStartOfBlocks: false
MacroBlockBegin: ''
MacroBlockEnd: ''
MaxEmptyLinesToKeep: 1
NamespaceIndentation: None
ObjCBinPackProtocolList: Auto
ObjCBlockIndentWidth: 4
ObjCSpaceAfterProperty: true
ObjCSpaceBeforeProtocolList: true
# Taken from git's rules
PenaltyBreakAssignment: 10
PenaltyBreakBeforeFirstCallParameter: 30
PenaltyBreakComment: 10
PenaltyBreakFirstLessLess: 0
PenaltyBreakString: 10
PenaltyExcessCharacter: 100
PenaltyReturnTypeOnItsOwnLine: 60
PointerAlignment: Right
ReflowComments: false
SortIncludes: false
SortUsingDeclarations: false
SpaceAfterCStyleCast: false
SpaceAfterTemplateKeyword: true
SpaceBeforeAssignmentOperators: true
SpaceBeforeCtorInitializerColon: true
SpaceBeforeInheritanceColon: true
SpaceBeforeParens: ControlStatementsExceptForEachMacros
SpaceBeforeRangeBasedForLoopColon: true
SpaceInEmptyParentheses: false
SpacesBeforeTrailingComments: 1
SpacesInAngles: false
SpacesInContainerLiterals: false
SpacesInCStyleCastParentheses: false
SpacesInParentheses: false
SpacesInSquareBrackets: false
Standard: Cpp03
TabWidth: 4
UseTab: Never
...
"#,
    );

    // .clang-tidy
    write_file(
        ".clang-tidy",
        r#"# .clang-tidy — Miru (C / Wayland)
# clang-tidy -p build src/*.c
WarningsAsErrors: ''
# Only lint project headers under src/ (skip generated protocol/ + system)
HeaderFilterRegex: '.*/src/.*'
FormatStyle: file
Checks: >
  -*,
  clang-analyzer-*,
  -clang-analyzer-security.insecureAPI.DeprecatedOrUnsafeBufferHandling,
  -clang-analyzer-security.ArrayBound,
  bugprone-*,
  -bugprone-easily-swappable-parameters,
  -bugprone-assignment-in-if-condition,
  -bugprone-narrowing-conversions,
  -bugprone-branch-clone,
  -bugprone-macro-parentheses,
  -bugprone-reserved-identifier,
  cert-*,
  -cert-err33-c,
  -cert-err34-c,
  -cert-dcl37-c,
  -cert-dcl51-cpp,
  misc-*,
  -misc-unused-parameters,
  -misc-no-recursion,
  -misc-include-cleaner,
  -misc-const-correctness,
  -misc-use-internal-linkage,
  performance-*,
  -performance-no-int-to-ptr,
  portability-*,
  readability-*,
  -readability-function-cognitive-complexity,
  -readability-function-size,
  -readability-identifier-length,
  -readability-magic-numbers,
  -readability-braces-around-statements,
  -readability-else-after-return,
  -readability-isolate-declaration,
  -readability-redundant-declaration,
  -readability-non-const-parameter,
  -readability-uppercase-literal-suffix,
  -readability-math-missing-parentheses,
  -readability-implicit-bool-conversion,
  -readability-identifier-naming,
  -readability-avoid-nested-conditional-operator,
  -clang-diagnostic-error
"#,
    );

    // .cmake-format.yaml
    write_file(
        ".cmake-format.yaml",
        r#"# cmake-format config for miru
# Docs: https://cmake-format.readthedocs.io/en/latest/configuration.html
# Install: pip install cmakelang[YAML]
# Usage:   cmake-format -i CMakeLists.txt cmake/*.cmake
parse:
  additional_commands: {}
  override_spec: {}
  vartags: []
  proptags: []
format:
  disable: false
  line_width: 120          # match .clang-format ColumnLimit
  tab_size: 2              # usual CMake indent
  use_tabchars: false
  fractional_tab_policy: use-space
  max_subgroups_hwrap: 2
  max_pargs_hwrap: 6
  max_rows_cmdline: 2
  separate_ctrl_name_with_space: false
  separate_fn_name_with_space: false
  dangle_parens: true      # closing ) on its own line when wrapped
  dangle_align: prefix
  min_prefix_chars: 4
  max_prefix_chars: 10
  max_lines_hwrap: 2
  line_ending: unix
  command_case: lower      # add_executable, target_link_libraries, …
  keyword_case: upper      # PRIVATE, PUBLIC, REQUIRED, …
  always_wrap: []
  enable_sort: true
  autosort: false
  require_valid_layout: false
  layout_passes: {}
markup:
  bullet_char: '*'
  enum_char: '.'
  first_comment_is_literal: true   # leave top-of-file license/header alone
  literal_comment_pattern: null
  enable_markup: false             # don't reflow # comments aggressively
lint:
  disabled_codes: []
  function_pattern: '[0-9a-z_]+'
  macro_pattern: '[0-9A-Z_]+'
  global_var_pattern: '[A-Z][0-9A-Z_]+'
  internal_var_pattern: '_[A-Z][0-9A-Z_]+'
  local_var_pattern: '[a-z][a-z0-9_]+'
  private_var_pattern: '_[0-9a-z_]+'
  public_var_pattern: '[A-Z][0-9A-Z_]+'
  keyword_pattern: '[A-Z][0-9A-Z_]+'
  max_conditionals_custom_parser: 2
  min_statement_spacing: 1
  max_statement_spacing: 2
  max_returns: 6
  max_branches: 12
  max_arguments: 5
  max_localvars: 15
  max_statements: 50
encode:
  emit_byteorder_mark: false
  input_encoding: utf-8
  output_encoding: utf-8
misc:
  per_command: {}
"#,
    );

    // Grimoire.toml with CMake commands
    write_file(
        "Grimoire.toml",
        &format!(
            r#"version = "1"

[ingredients]
project = "{}"
build_dir = "build"

[sigil.configure]
description = "Configure CMake (out-of-source)"
language = "shell"
silent = true
run = "cmake -B {{{{build_dir}}}} -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"

[sigil.build]
description = "Build with CMake"
language = "shell"
silent = true
run = '''
cmake -B {{{{build_dir}}}} -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build {{{{build_dir}}}} -j$(nproc)
'''

[sigil.run]
description = "Build and run"
language = "shell"
silent = true
run = '''
cmake -B {{{{build_dir}}}} -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build {{{{build_dir}}}} -j$(nproc)
./{{{{build_dir}}}}/{{{{project}}}}
'''

[sigil.br]
description = "Build + Run"
language = "shell"
silent = true
run = '''
cmake -B {{{{build_dir}}}} -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build {{{{build_dir}}}} -j$(nproc)
./{{{{build_dir}}}}/{{{{project}}}}
'''

[sigil.clean]
description = "Remove build directory"
language = "shell"
silent = true
run = "rm -rf {{{{build_dir}}}}"

[sigil.fmt]
description = "Format sources with clang-format"
language = "shell"
silent = false
run = "clang-format -i main.c"

[sigil.tidy]
description = "Run clang-tidy (requires configure first)"
language = "shell"
silent = false
run = "clang-tidy -p {{{{build_dir}}}} main.c"

[sigil.cmake-fmt]
description = "Format CMakeLists.txt with cmake-format"
language = "shell"
silent = false
run = "cmake-format -i CMakeLists.txt"
"#,
            project_name
        ),
    );

    // Optional: symlink compile_commands.json for clangd
    // (user can run configure first)

    println!("✅ Complex C project '{}' created!", project_name);
    println!("📦 Layout:");
    println!("   main.c");
    println!("   CMakeLists.txt");
    println!("   .clang-format");
    println!("   .clang-tidy");
    println!("   .cmake-format.yaml");
    println!("   Grimoire.toml");
    println!();
    println!("🔨 Typical workflow:");
    println!("   grimoire configure   # or just grimoire build");
    println!("   grimoire build");
    println!("   grimoire run");
    println!("   grimoire fmt");
    println!("   grimoire tidy");
}

// ==================== Rust ====================
fn create_rust() {
    println!("🦀 Creating Rust project...");
    let project_name = prompt_project_name();
    if Command::new("cargo").arg("--version").output().is_err() {
        eprintln!("Error: cargo not found.");
        exit(1);
    }
    let status = Command::new("cargo")
        .args(["new", "--bin", &project_name])
        .status()
        .expect("Failed to run cargo new");
    if !status.success() {
        exit(1);
    }
    println!("✅ Rust project '{}' created!", project_name);
}

// ==================== Python ====================
fn create_python() {
    println!("🐍 Creating Python project...");
    let project_name = prompt_project_name();
    if Command::new("uv").arg("--version").output().is_err() {
        eprintln!("Error: uv not found.");
        exit(1);
    }
    let status = Command::new("uv")
        .args(["init", &project_name])
        .status()
        .expect("Failed to run uv init");
    if !status.success() {
        exit(1);
    }
    println!("✅ Python project '{}' created!", project_name);
}

// ==================== Go ====================
fn create_go() {
    println!("🐹 Creating Go project...");
    let project_name = prompt_project_name();
    create_dir_and_cd(&project_name);
    let status = Command::new("go")
        .args(["mod", "init", &project_name])
        .status()
        .expect("Failed to run go mod init");
    if !status.success() {
        exit(1);
    }
    write_file(
        "main.go",
        r#"package main
import "fmt"
func main() {
    fmt.Println("Hello, Go!")
}
"#,
    );
    write_file(
        "Grimoire.toml",
        r#"version = "1"
[sigil.run]
description = "Run the Go project"
language = "shell"
silent = true
run = "go run ."
[sigil.build]
description = "Build the binary"
language = "shell"
silent = true
run = "go build -o main ."
[sigil.clean]
description = "Remove the binary"
language = "shell"
silent = true
run = "rm -f main"
"#,
    );
    println!("✅ Go project '{}' created!", project_name);
}

// ==================== Zig ====================
fn create_zig() {
    println!("⚡ Creating Zig project...");
    let project_name = prompt_project_name();
    create_dir_and_cd(&project_name);
    let status = Command::new("zig")
        .arg("init")
        .status()
        .expect("Failed to run zig init");
    if !status.success() {
        exit(1);
    }
    write_file(
        "Grimoire.toml",
        r#"version = "1"
[sigil.run]
description = "Run the Zig project"
language = "shell"
silent = true
run = "zig build run"
[sigil.build]
description = "Build the project"
language = "shell"
silent = true
run = "zig build"
[sigil.clean]
description = "Clean build artifacts"
language = "shell"
silent = true
run = "rm -rf zig-out .zig-cache"
"#,
    );
    println!("✅ Zig project '{}' created!", project_name);
}

// ==================== ESP32-Std ====================
fn create_esp32_std() {
    println!("🔧 Creating ESP32 Rust (std) project...");
    let project_name = prompt_project_name();
    if Command::new("cargo-generate").arg("--version").output().is_err() {
        println!("Installing cargo-generate...");
        let status = Command::new("cargo")
            .args(["install", "cargo-generate"])
            .status()
            .expect("Failed to install cargo-generate");
        if !status.success() {
            exit(1);
        }
    }
    let status = Command::new("cargo")
        .args([
            "generate",
            "esp-rs/esp-idf-template",
            "cargo",
            "--name",
            &project_name,
        ])
        .status()
        .expect("Failed to run cargo generate");
    if !status.success() {
        exit(1);
    }
    env::set_current_dir(&project_name).expect("Failed to cd into project");
    println!("📊 Adding build-size.sh profiling script...");
    write_file(
        "build-size.sh",
        r#"#!/usr/bin/env zsh
set -e
WORKSPACE_ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="riscv32imc-esp-espidf"
# gruvbox colors
local rst='\033[0m'
local bold='\033[1m'
local dim='\033[2m'
local bg0='\033[38;2;40;40;40m'
local fg='\033[38;2;235;219;178m'
local fg0='\033[38;2;251;241;199m'
local red='\033[38;2;251;73;52m'
local green='\033[38;2;184;187;38m'
local yellow='\033[38;2;250;189;47m'
local blue='\033[38;2;131;165;152m'
local purple='\033[38;2;211;134;155m'
local aqua='\033[38;2;142;192;124m'
local orange='\033[38;2;254;128;25m'
local gray='\033[38;2;146;131;116m'
# ESP32-C3 typical specs
FLASH_MAX=$((4096 * 1024)) # 4MB
RAM_MAX=$((400 * 1024)) # ~400KB internal SRAM
# prerequisite checks
missing=()
if ! command -v cargo &>/dev/null; then
    missing+=(" ${orange}cargo${rst} ${gray}https://rustup.rs${rst}")
fi
if ! command -v jq &>/dev/null; then
    missing+=(" ${orange}jq${rst} ${gray}install via system package manager${rst}")
fi
if ! command -v rust-size &>/dev/null; then
    missing+=(" ${orange}rust-size${rst} ${gray}cargo install cargo-binutils && rustup component add llvm-tools${rst}")
fi
if ! command -v bc &>/dev/null; then
    missing+=(" ${orange}bc${rst} ${gray}install via system package manager${rst}")
fi
if (( ${#missing} > 0 )); then
    printf "${red}${bold}missing required tools:${rst}\n"
    for m in "${missing[@]}"; do
        printf "$m\n"
    done
    exit 1
fi
usage() {
    echo "Usage: ./build-size.sh <project>"
    exit 1
}
bar() {
    local used=$1 max=$2 width=40
    local pct=$((used * 100 / max))
    local filled=$((used * width / max))
    (( filled > width )) && filled=$width
    local empty=$((width - filled))
    local color=$green
    (( pct > 70 )) && color=$yellow
    (( pct > 90 )) && color=$orange
    (( pct > 98 )) && color=$red
    printf "${dim}[${rst}"
    printf "${color}%${filled}s${rst}" | tr ' ' '#'
    printf "${gray}%${empty}s${rst}" | tr ' ' '.'
    printf "${dim}]${rst}"
    printf " ${color}${bold}%d%%${rst}" "$pct"
}
print_section() {
    local name=$1 size=$2 color=$3
    printf " ${color}%-18s${rst} ${fg}%'10d${rst} ${gray}bytes${rst} ${dim}(%6.1f KB)${rst}\n" \
        "$name" "$size" "$(echo "scale=1; $size / 1024" | bc)"
}
if [[ $# -lt 1 ]]; then
    usage
fi
project="$1"
project_dir="$WORKSPACE_ROOT/$project"
if [[ ! -d "$project_dir" ]]; then
    echo "${red}error:${rst} project '$project' not found"
    exit 1
fi
# 2. Get Cargo metadata
METADATA="$(cargo metadata --no-deps --format-version 1 --manifest-path "$project_dir/Cargo.toml" 2>/dev/null)"
TARGET_DIR="$(echo "$METADATA" | jq -r '.target_directory')"
if [[ -z "$TARGET_DIR" || "$TARGET_DIR" == "null" ]]; then
    echo "${red}error:${rst} failed to determine target directory via cargo metadata"
    exit 1
fi
# Extract the exact binary name from Cargo.toml so we don't guess based on the folder path
BIN_NAME="$(echo "$METADATA" | jq -r '.packages[0].targets[] | select(.kind[] == "bin") | .name' | head -n 1)"
BINARY_DIR="$TARGET_DIR/$TARGET/release"
# 3. Build and calculate sizes
cd "$project_dir"
printf "${dim}building ${fg0}${bold}$BIN_NAME${rst} ${dim}(release, $TARGET)${rst}\n"
cargo build --release --target "$TARGET" 2>&1
binary="$BINARY_DIR/$BIN_NAME"
if [[ ! -f "$binary" ]]; then
    echo "${red}error:${rst} binary not found at $binary"
    exit 1
fi
# parse ESP-IDF sections
typeset -A sections
while read -r name size _addr; do
    sections[$name]=$size
done < <(rust-size -A "$binary" | grep -E '^\.')
# Flash takes the flash text/rodata, plus the initial values for DRAM and IRAM
flash_total=$(( ${sections[.flash.text]:-0} + ${sections[.flash.rodata]:-0} + ${sections[.dram0.data]:-0} + ${sections[.iram0.text]:-0} ))
# RAM is the sum of Instruction RAM (IRAM) and Data RAM (DRAM)
ram_total=$(( ${sections[.iram0.text]:-0} + ${sections[.iram0.vectors]:-0} + ${sections[.dram0.data]:-0} + ${sections[.dram0.bss]:-0} ))
echo ""
printf "${yellow}${bold} FLASH${rst} "
bar $flash_total $FLASH_MAX
printf " ${dim}%'d / %'d bytes${rst}\n" $flash_total $FLASH_MAX
echo ""
print_section ".flash.text" "${sections[.flash.text]:-0}" "$blue"
print_section ".flash.rodata" "${sections[.flash.rodata]:-0}" "$purple"
print_section ".iram0.text" "${sections[.iram0.text]:-0}" "$aqua"
print_section ".dram0.data" "${sections[.dram0.data]:-0}" "$orange"
echo ""
printf "${aqua}${bold} RAM${rst} "
bar $ram_total $RAM_MAX
printf " ${dim}%'d / %'d bytes${rst}\n" $ram_total $RAM_MAX
echo ""
print_section ".iram0.text" "${sections[.iram0.text]:-0}" "$blue"
print_section ".iram0.vectors" "${sections[.iram0.vectors]:-0}" "$aqua"
print_section ".dram0.data" "${sections[.dram0.data]:-0}" "$orange"
print_section ".dram0.bss" "${sections[.dram0.bss]:-0}" "$gray"
echo ""
"#,
    );
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata("build-size.sh").unwrap().permissions();
        perms.set_mode(0o755);
        fs::set_permissions("build-size.sh", perms).ok();
    }
    println!("📝 Writing Grimoire.toml...");
    write_file(
        "Grimoire.toml",
        r#"version = "1"
[sigil.sz]
description = "Show binary size"
language = "shell"
silent = true
run = "./build-size.sh ."
[sigil.f]
description = "Size + Run (release)"
language = "shell"
silent = true
run = '''
./build-size.sh .
cargo run --release
'''
"#,
    );
    println!("✅ ESP32 project '{}' created with memory profiling tools!", project_name);
}

// ==================== STM32-Embassy ====================
fn create_stm32_embassy() {
    println!("🦀 Creating STM32 Embassy (no-std) project...");
    let project_name = prompt_project_name();
    println!("⚙️ Checking Rust target...");
    let _ = Command::new("rustup")
        .args(["target", "add", "thumbv7m-none-eabi"])
        .status();
    println!("📦 Initializing Cargo project...");
    let status = Command::new("cargo")
        .args(["new", "--bin", &project_name])
        .status()
        .expect("Failed to run cargo new");
    if !status.success() {
        exit(1);
    }
    env::set_current_dir(&project_name).expect("Failed to cd");
    println!("➕ Adding dependencies...");
    let deps = [
        ("cortex-m", &["--features", "inline-asm,critical-section-single-core"][..]),
        ("cortex-m-rt", &[][..]),
        ("panic-halt", &[][..]),
        ("heapless", &[][..]),
        ("embassy-executor", &["--features", "executor-thread"][..]),
        (
            "embassy-stm32",
            &["--features", "stm32f103c8,unstable-pac,memory-x,time-driver-any,exti"][..],
        ),
        ("embassy-time", &["--features", "tick-hz-1_000_000"][..]),
    ];
    for (crate_name, features) in deps {
        let mut cmd = Command::new("cargo");
        cmd.arg("add").arg(crate_name);
        for f in features {
            cmd.arg(f);
        }
        let status = cmd.status().expect("Failed to run cargo add");
        if !status.success() {
            eprintln!("Warning: failed to add {}", crate_name);
        }
    }
    println!("⚙️ Configuring build target...");
    fs::create_dir_all(".cargo").ok();
    write_file(
        ".cargo/config.toml",
        r#"[target.'cfg(all(target_arch = "arm", target_os = "none"))']
runner = "probe-rs run --chip STM32F103C8"
rustflags = [
  "-C", "link-arg=-Tlink.x",
]
[build]
target = "thumbv7m-none-eabi"
[env]
DEFMT_LOG = "trace"
"#,
    );
    write_file(
        "Embed.toml",
        r#"[default.general]
chip = "STM32F103C8"
[default.reset]
halt_afterwards = false
[default.rtt]
enabled = false
[default.gdb]
enabled = false
"#,
    );
    println!("📝 Writing main.rs...");
    write_file(
        "src/main.rs",
        r#"#![no_std]
#![no_main]
use panic_halt as _;
use embassy_executor::Spawner;
use embassy_stm32::usart::{Config, UartTx, InterruptHandler};
use embassy_stm32::peripherals;
use embassy_time::Timer;
use core::fmt::Write;
use heapless::String;
use embassy_stm32::bind_interrupts;
bind_interrupts!(struct Irqs {
    USART1 => InterruptHandler<peripherals::USART1>;
});
#[embassy_executor::main]
async fn main(_spawner: Spawner) {
    let p = embassy_stm32::init(Default::default());
    let mut tx = UartTx::new(p.USART1, p.PA9, p.DMA1_CH4, Config::default()).unwrap();
    loop {
        let mut s: String<64> = String::new();
        let _ = writeln!(s, "Embassy Running! Uptime: {}s\r\n", embassy_time::Instant::now().as_secs());
       
        let _ = tx.write(s.as_bytes()).await;
        Timer::after_millis(1000).await;
    }
}
"#,
    );
    write_file(
        "Grimoire.toml",
        r#"version = "1"
[sigil.run]
description = "Build and flash"
language = "shell"
silent = true
run = "cargo run"
[sigil.build]
description = "Release build"
language = "shell"
silent = true
run = "cargo build --release"
[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = "cargo clean"
"#,
    );
    println!("✅ STM32 project '{}' created!", project_name);
    println!("📝 Hardware: STM32F103C8 (Blue Pill)");
    println!("🔌 Wiring: Connect PA9 (TX) to FTDI RX");
    println!("🔨 Run 'grimoire run' to flash.");
}

// ==================== RP2040-HAL ====================
fn create_rp2040_hal() {
    println!("🍓 Creating RP2040 (no-std) project...");
    let project_name = prompt_project_name();
    println!("⚙️ Checking Rust target...");
    let _ = Command::new("rustup")
        .args(["target", "add", "thumbv6m-none-eabi"])
        .status();
    println!("📦 Initializing Cargo project...");
    let status = Command::new("cargo")
        .args(["new", "--bin", &project_name])
        .status()
        .expect("Failed to run cargo new");
    if !status.success() {
        exit(1);
    }
    env::set_current_dir(&project_name).expect("Failed to cd");
    // Force edition 2024
    let cargo_toml = fs::read_to_string("Cargo.toml").expect("Failed to read Cargo.toml");
    let new_cargo = cargo_toml.replace("edition = \"2021\"", "edition = \"2024\"");
    write_file("Cargo.toml", &new_cargo);
    println!("➕ Adding dependencies...");
    let deps = [
        ("cortex-m", &[][..]),
        ("cortex-m-rt", &[][..]),
        ("embedded-hal", &[][..]),
        ("fugit", &[][..]),
        ("panic-halt", &[][..]),
        ("rp2040-boot2", &[][..]),
        ("rp2040-hal", &["--features", "critical-section-impl"][..]),
    ];
    for (crate_name, features) in deps {
        let mut cmd = Command::new("cargo");
        cmd.arg("add").arg(crate_name);
        for f in features {
            cmd.arg(f);
        }
        let _ = cmd.status();
    }
    println!("⚙️ Configuring build profiles...");
    let mut cargo_toml = fs::read_to_string("Cargo.toml").unwrap();
    cargo_toml.push_str(&format!(
        r#"
[[bin]]
name = "{}"
test = false
bench = false
doctest = false
[profile.dev]
codegen-units = 1
debug = 2
debug-assertions = true
incremental = false
opt-level = 3
overflow-checks = true
[profile.release]
codegen-units = 1
debug = 2
debug-assertions = false
incremental = false
lto = 'fat'
opt-level = 3
overflow-checks = false
"#,
        project_name
    ));
    write_file("Cargo.toml", &cargo_toml);
    println!("⚙️ Configuring build target...");
    fs::create_dir_all(".cargo").ok();
    write_file(
        ".cargo/config.toml",
        r#"[build]
target = "thumbv6m-none-eabi"
[target.'cfg(all(target_arch = "arm", target_os = "none"))']
runner = "elf2uf2-rs deploy --family rp2040"
linker = "flip-link"
rustflags = [
  "-C", "link-arg=--nmagic",
  "-C", "link-arg=-Tlink.x",
  "-C", "no-vectorize-loops",
]
[env]
DEFMT_LOG = "debug"
"#,
    );
    println!("🧠 Configuring memory map...");
    write_file(
        "memory.x",
        r#"MEMORY {
    BOOT2 : ORIGIN = 0x10000000, LENGTH = 0x100
    FLASH : ORIGIN = 0x10000100, LENGTH = 2048K - 0x100
    RAM : ORIGIN = 0x20000000, LENGTH = 256K
}
EXTERN(BOOT2_FIRMWARE)
SECTIONS {
    /* ### Boot loader */
    .boot2 ORIGIN(BOOT2) :
    {
        KEEP(*(.boot2));
    } > BOOT2
} INSERT BEFORE .text;
"#,
    );
    println!("📝 Writing main.rs...");
    write_file(
        "src/main.rs",
        r#"#![no_std]
#![no_main]
use cortex_m_rt::entry;
use panic_halt as _;
use rp2040_hal::{
    clocks::{init_clocks_and_plls, Clock},
    pac,
    pio::PIOExt,
    timer::Timer,
    watchdog::Watchdog,
    Sio,
};
// --- THE IGNITION KEY ---
// This places the 256-byte bootloader at the very start of the flash memory.
// Without this, the RP2040 ROM refuses to jump to our code.
#[unsafe(link_section = ".boot2")]
#[used]
pub static BOOT2: [u8; 256] = rp2040_boot2::BOOT_LOADER_W25Q080;
// ------------------------
#[entry]
fn main() -> ! {
    let mut pac = pac::Peripherals::take().unwrap();
    let cp = pac::CorePeripherals::take().unwrap();
   
    let mut wdt = Watchdog::new(pac.WATCHDOG);
    let clocks = init_clocks_and_plls(
        12_000_000u32,
        pac.XOSC,
        pac.CLOCKS,
        pac.PLL_SYS,
        pac.PLL_USB,
        &mut pac.RESETS,
        &mut wdt,
    )
    .ok()
    .unwrap();
    let timer = Timer::new(pac.TIMER, &mut pac.RESETS, &clocks);
    let mut delay = cortex_m::delay::Delay::new(cp.SYST, clocks.system_clock.freq().to_Hz());
    let sio = Sio::new(pac.SIO);
    let pins = rp2040_hal::gpio::Pins::new(
        pac.IO_BANK0,
        pac.PADS_BANK0,
        sio.gpio_bank0,
        &mut pac.RESETS,
    );
    loop {
        cortex_m::asm::wfi();
    }
}
"#,
    );
    println!("🧹 Downloading flash_nuke.uf2 utility...");
    let _ = Command::new("curl")
        .args([
            "-L",
            "-s",
            "-o",
            "flash_nuke.uf2",
            "https://raw.githubusercontent.com/Pwea/Flash-Nuke/main/flash_nuke.uf2",
        ])
        .status();
    println!("📊 Adding build-size.sh profiling script...");
    write_file(
        "build-size.sh",
        r#"#!/usr/bin/env zsh
set -e
WORKSPACE_ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="thumbv6m-none-eabi"
# gruvbox colors
local rst='\033[0m'
local bold='\033[1m'
local dim='\033[2m'
local bg0='\033[38;2;40;40;40m'
local fg='\033[38;2;235;219;178m'
local fg0='\033[38;2;251;241;199m'
local red='\033[38;2;251;73;52m'
local green='\033[38;2;184;187;38m'
local yellow='\033[38;2;250;189;47m'
local blue='\033[38;2;131;165;152m'
local purple='\033[38;2;211;134;155m'
local aqua='\033[38;2;142;192;124m'
local orange='\033[38;2;254;128;25m'
local gray='\033[38;2;146;131;116m'
FLASH_MAX=$((2048 * 1024))
RAM_MAX=$((256 * 1024))
# prerequisite checks
missing=()
if ! command -v cargo &>/dev/null; then
    missing+=(" ${orange}cargo${rst} ${gray}https://rustup.rs${rst}")
fi
if ! command -v jq &>/dev/null; then
    missing+=(" ${orange}jq${rst} ${gray}install via system package manager${rst}")
fi
if ! command -v flip-link &>/dev/null; then
    missing+=(" ${orange}flip-link${rst} ${gray}cargo install flip-link${rst}")
fi
if ! command -v rust-size &>/dev/null; then
    missing+=(" ${orange}rust-size${rst} ${gray}cargo install cargo-binutils && rustup component add llvm-tools${rst}")
fi
if ! command -v bc &>/dev/null; then
    missing+=(" ${orange}bc${rst} ${gray}install via system package manager${rst}")
fi
if (( ${#missing} > 0 )); then
    printf "${red}${bold}missing required tools:${rst}\n"
    for m in "${missing[@]}"; do
        printf "$m\n"
    done
    exit 1
fi
usage() {
    echo "Usage: ./build-size.sh <project>"
    exit 1
}
bar() {
    local used=$1 max=$2 width=40
    local pct=$((used * 100 / max))
    local filled=$((used * width / max))
    (( filled > width )) && filled=$width
    local empty=$((width - filled))
    local color=$green
    (( pct > 70 )) && color=$yellow
    (( pct > 90 )) && color=$orange
    (( pct > 98 )) && color=$red
    printf "${dim}[${rst}"
    printf "${color}%${filled}s${rst}" | tr ' ' '#'
    printf "${gray}%${empty}s${rst}" | tr ' ' '.'
    printf "${dim}]${rst}"
    printf " ${color}${bold}%d%%${rst}" "$pct"
}
print_section() {
    local name=$1 size=$2 color=$3
    printf " ${color}%-18s${rst} ${fg}%'10d${rst} ${gray}bytes${rst} ${dim}(%6.1f KB)${rst}\n" \
        "$name" "$size" "$(echo "scale=1; $size / 1024" | bc)"
}
# 1. Parse arguments and check directories first
if [[ $# -lt 1 ]]; then
    usage
fi
project="$1"
project_dir="$WORKSPACE_ROOT/$project"
if [[ ! -d "$project_dir" ]]; then
    echo "${red}error:${rst} project '$project' not found"
    exit 1
fi
# 2. Get Cargo metadata
METADATA="$(cargo metadata --no-deps --format-version 1 --manifest-path "$project_dir/Cargo.toml" 2>/dev/null)"
TARGET_DIR="$(echo "$METADATA" | jq -r '.target_directory')"
if [[ -z "$TARGET_DIR" || "$TARGET_DIR" == "null" ]]; then
    echo "${red}error:${rst} failed to determine target directory via cargo metadata"
    exit 1
fi
# Extract exact binary name to support "." as argument
BIN_NAME="$(echo "$METADATA" | jq -r '.packages[0].targets[] | select(.kind[] == "bin") | .name' | head -n 1)"
BINARY_DIR="$TARGET_DIR/$TARGET/release"
# 3. Build and calculate sizes
cd "$project_dir"
printf "${dim}building ${fg0}${bold}$BIN_NAME${rst} ${dim}(release, $TARGET)${rst}\n"
cargo build --release --target "$TARGET" 2>&1
binary="$BINARY_DIR/$BIN_NAME"
if [[ ! -f "$binary" ]]; then
    echo "${red}error:${rst} binary not found at $binary"
    exit 1
fi
# parse sections
typeset -A sections
while read -r name size _addr; do
    sections[$name]=$size
done < <(rust-size -A "$binary" | grep -E '^\.')
flash_total=$(( ${sections[.boot2]:-0} + ${sections[.vector_table]:-0} + ${sections[.text]:-0} + ${sections[.rodata]:-0} + ${sections[.data]:-0} ))
ram_total=$(( ${sections[.data]:-0} + ${sections[.bss]:-0} + ${sections[.uninit]:-0} ))
echo ""
printf "${yellow}${bold} FLASH${rst} "
bar $flash_total $FLASH_MAX
printf " ${dim}%'d / %'d bytes${rst}\n" $flash_total $FLASH_MAX
echo ""
print_section ".text" "${sections[.text]:-0}" "$blue"
print_section ".rodata" "${sections[.rodata]:-0}" "$purple"
print_section ".vector_table" "${sections[.vector_table]:-0}" "$aqua"
print_section ".boot2" "${sections[.boot2]:-0}" "$aqua"
print_section ".data" "${sections[.data]:-0}" "$orange"
echo ""
printf "${aqua}${bold} RAM${rst} "
bar $ram_total $RAM_MAX
printf " ${dim}%'d / %'d bytes${rst}\n" $ram_total $RAM_MAX
echo ""
print_section ".bss" "${sections[.bss]:-0}" "$blue"
print_section ".data" "${sections[.data]:-0}" "$orange"
print_section ".uninit" "${sections[.uninit]:-0}" "$gray"
echo ""
"#,
    );
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata("build-size.sh").unwrap().permissions();
        perms.set_mode(0o755);
        fs::set_permissions("build-size.sh", perms).ok();
    }
    write_file(
        "Grimoire.toml",
        r#"version = "1"
[sigil.build]
description = "Release build"
language = "shell"
silent = true
run = "cargo build --release"
[sigil.sz]
description = "Show size"
language = "shell"
silent = true
run = "./build-size.sh ."
[sigil.run]
description = "Build, convert to UF2 and flash"
language = "shell"
silent = false
run = '''
./build-size.sh .
echo "📦 Converting ELF to UF2..."
elf2uf2-rs convert target/thumbv6m-none-eabi/release/$(basename "$PWD") flash.uf2
echo "🔌 Mounting RP2040..."
sudo mount -t vfat -o sync /dev/sda1 /mnt/rp2
echo "⚡ Flashing..."
sudo cp flash.uf2 /mnt/rp2/
echo "✅ Done!"
sudo umount /mnt/rp2/ || true
'''
[sigil.nuke]
description = "Nuke flash memory"
language = "shell"
silent = false
run = '''
echo "🧹 Nuking RP2040 flash memory..."
if mountpoint -q /mnt/rp2; then
    echo "✓ Already mounted"
else
    sudo mount -t vfat -o sync /dev/sda1 /mnt/rp2
fi
sudo cp flash_nuke.uf2 /mnt/rp2/
sleep 2
sudo umount /mnt/rp2/ || true
echo "✅ Flash memory nuked!"
'''
[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = '''
cargo clean
rm -f flash.uf2
'''
"#,
    );
    println!("✅ RP2040 project '{}' created with memory profiling!", project_name);
    println!("📝 Hardware: Waveshare RP2040 Zero");
    println!("🔌 NeoPixel on GP16");
    println!("🔨 Run 'grimoire run' to flash.");
}

// ==================== nRF52-Embassy ====================
fn create_nrf52_embassy() {
    println!("📡 Creating nRF52840 Embassy (no-std) project...");
    let project_name = prompt_project_name();
    println!("⚙️ Checking Rust target...");
    let _ = Command::new("rustup")
        .args(["target", "add", "thumbv7em-none-eabi"])
        .status();
    println!("📦 Initializing Cargo project...");
    let status = Command::new("cargo")
        .args(["new", "--bin", &project_name, "--vcs", "none"])
        .status()
        .expect("Failed to run cargo new");
    if !status.success() {
        exit(1);
    }
    env::set_current_dir(&project_name).expect("Failed to cd");
    println!("➕ Adding dependencies...");
    let deps = [
        (
            "embassy-executor",
            &["--features", "platform-cortex-m,executor-thread,defmt"][..],
        ),
        (
            "embassy-time",
            &["--features", "defmt,defmt-timestamp-uptime,tick-hz-32_768"][..],
        ),
        (
            "embassy-nrf",
            &["--features", "defmt,nrf52840,time-driver-rtc1,gpiote"][..],
        ),
        ("defmt", &[][..]),
        ("defmt-rtt", &[][..]),
        ("panic-probe", &["--features", "print-defmt"][..]),
        (
            "cortex-m",
            &["--features", "inline-asm,critical-section-single-core"][..],
        ),
        ("cortex-m-rt", &[][..]),
    ];
    for (crate_name, features) in deps {
        let mut cmd = Command::new("cargo");
        cmd.arg("add").arg(crate_name);
        for f in features {
            cmd.arg(f);
        }
        let _ = cmd.status();
    }
    // Append profiles
    let mut cargo_toml = fs::read_to_string("Cargo.toml").unwrap();
    cargo_toml.push_str(&format!(
        r#"
[profile.release]
debug = 2
lto = true
opt-level = 'z' # Optimize for size
[[bin]]
name = "{}"
test = false
bench = false
doctest = false
"#,
        project_name
    ));
    write_file("Cargo.toml", &cargo_toml);
    fs::create_dir_all(".cargo").ok();
    write_file(
        ".cargo/config.toml",
        r#"[target.'cfg(all(target_arch = "arm", target_os = "none"))']
# replace nRF52840_xxAA with your chip as listed in `probe-rs chip list`
runner = "probe-rs run --chip nRF52840_xxAA"
[build]
target = "thumbv7em-none-eabi"
[env]
DEFMT_LOG = "trace"
"#,
    );
    write_file(
        "memory.x",
        r#"MEMORY
{
  /* NOTE 1 K = 1 KiBi = 1024 bytes */
  FLASH : ORIGIN = 0x00000000, LENGTH = 1024K
  RAM : ORIGIN = 0x20000000, LENGTH = 256K
  /* These values correspond to the NRF52840 with Softdevices S140 7.3.0 */
  /*
     FLASH : ORIGIN = 0x00027000, LENGTH = 868K
     RAM : ORIGIN = 0x20020000, LENGTH = 128K
  */
}
"#,
    );
    write_file(
        "build.rs",
        r#"//! This build script copies the `memory.x` file from the crate root into
//! a directory where the linker can always find it at build time.
use std::env;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;
fn main() {
    let out = &PathBuf::from(env::var_os("OUT_DIR").unwrap());
    File::create(out.join("memory.x"))
        .unwrap()
        .write_all(include_bytes!("memory.x"))
        .unwrap();
    println!("cargo:rustc-link-search={}", out.display());
    println!("cargo:rerun-if-changed=memory.x");
    println!("cargo:rustc-link-arg-bins=--nmagic");
    println!("cargo:rustc-link-arg-bins=-Tlink.x");
    println!("cargo:rustc-link-arg-bins=-Tdefmt.x");
}
"#,
    );
    write_file(
        "src/main.rs",
        r#"#![no_std]
#![no_main]
use defmt::info;
use defmt_rtt as _; // Initializes the global defmt logger
use panic_probe as _; // Catches panics and sends them through defmt
use embassy_executor::Spawner;
use embassy_nrf::gpio::{Level, Output, OutputDrive};
use embassy_time::{Duration, Timer};
#[embassy_executor::main]
async fn main(_spawner: Spawner) {
    // Initialize the HAL and grab the peripheral singleton
    let p = embassy_nrf::init(Default::default());
    loop {}
}
"#,
    );
    write_file(
        "Grimoire.toml",
        r#"version = "1"
[sigil.run]
description = "Build and flash with defmt"
language = "shell"
silent = true
run = "cargo run"
[sigil.build]
description = "Release build"
language = "shell"
silent = true
run = "cargo build --release"
[sigil.sz]
description = "Show size"
language = "shell"
silent = true
run = "./build-size.sh ."
[sigil.f]
description = "Size + Run release"
language = "shell"
silent = true
run = '''
./build-size.sh .
cargo run --release
'''
[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = "cargo clean"
"#,
    );
    println!("✅ nRF52840 Embassy project '{}' created!", project_name);
    println!("🔌 Connect your nRF52840-DK and run 'grimoire run' to compile, flash, and view defmt logs.");
}

// ==================== Zephyr ====================
fn create_zephyr() {
    println!("🪁 Creating Zephyr RTOS project...");
    let project_name = prompt_project_name();
    let boards = vec![
        "nucleo_l433rc_p",
        "nrf52840dk/nrf52840",
        "frdm_mcxa156",
        "frdm_mcxn236",
        "rp2040_zero",
    ];
    let board = match Select::new("Choose board:", boards)
        .with_page_size(10)
        .prompt()
    {
        Ok(b) => b,
        Err(_) => {
            println!("Aborted.");
            exit(0);
        }
    };
    let flash_runner = if board.contains("frdm_mcxa156") || board.contains("frdm_mcxn236") {
        "jlink"
    } else if board == "rp2040_zero" {
        "uf2"
    } else {
        "openocd"
    };
    fs::create_dir_all(format!("{}/src", project_name)).ok();
    write_file(
        &format!("{}/CMakeLists.txt", project_name),
        &format!(
            r#"cmake_minimum_required(VERSION 3.20.0)
find_package(Zephyr REQUIRED HINTS $ENV{{ZEPHYR_BASE}})
project({})
# Export compile commands for clangd / Neovim
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
target_sources(app PRIVATE src/main.c)
"#,
            project_name
        ),
    );
    write_file(
        &format!("{}/prj.conf", project_name),
        r#"# CONFIG_PRINTK=y
# CONFIG_LOG=y
# CONFIG_GPIO=y
"#,
    );
    write_file(
        &format!("{}/src/main.c", project_name),
        r#"#include <zephyr/kernel.h>
int main(void)
{
    return 0;
}
"#,
    );
    // Write Grimoire.toml
    if board == "rp2040_zero" {
        write_file(
            &format!("{}/Grimoire.toml", project_name),
            r#"version = "1"
[sigil.build]
description = "Build"
language = "shell"
silent = true
run = "west build -b rp2040_zero ."
[sigil.pristine]
description = "Pristine build"
language = "shell"
silent = true
run = "west build -p always -b rp2040_zero ."
[sigil.flash]
description = "Flash UF2"
language = "shell"
silent = false
run = '''
echo "Looking for RP2040 in bootloader mode..."
DEV=$(lsblk -o NAME,LABEL -n -l | awk '$2=="RPI-RP2" {print "/dev/"$1}')
if [ -z "$DEV" ]; then
    echo "❌ No RPI-RP2 found!"
    echo " → Hold BOOT button, plug in USB (or press RESET while holding BOOT)"
    echo " → Then run 'grimoire flash' again"
    exit 1
fi
echo "✓ Found board at $DEV"
sudo mkdir -p /mnt/rp2
if ! mountpoint -q /mnt/rp2; then
    sudo mount -t vfat -o sync,uid=$(id -u),gid=$(id -g) "$DEV" /mnt/rp2
fi
echo "⚡ Flashing..."
cp build/zephyr/zephyr.uf2 /mnt/rp2/
echo "✅ Done! Board should reboot."
sleep 1.5
sudo umount /mnt/rp2 || true
'''
[sigil.nuke]
description = "Nuke flash"
language = "shell"
silent = false
run = '''
echo "🧹 Nuking RP2040 flash memory..."
DEV=$(lsblk -o NAME,LABEL -n -l | awk '$2=="RPI-RP2" {print "/dev/"$1}')
if [ -z "$DEV" ]; then
    echo "❌ No RPI-RP2 found! Put the board into bootloader mode first."
    exit 1
fi
sudo mkdir -p /mnt/rp2
if ! mountpoint -q /mnt/rp2; then
    sudo mount -t vfat -o sync,uid=$(id -u),gid=$(id -g) "$DEV" /mnt/rp2
fi
if [ ! -f flash_nuke.uf2 ]; then
    echo "⬇️ Downloading flash_nuke.uf2..."
    curl -L -s -o flash_nuke.uf2 https://raw.githubusercontent.com/Pwea/Flash-Nuke/main/flash_nuke.uf2
fi
echo "💣 Copying flash_nuke.uf2..."
cp flash_nuke.uf2 /mnt/rp2/
echo "⏳ Waiting for flash erase..."
sleep 2
sudo umount /mnt/rp2 || true
echo "✅ Flash memory nuked! Board will reboot."
'''
[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = "rm -rf build compile_commands.json"
"#,
        );
    } else {
        let mut grimoire = format!(
            r#"version = "1"
[sigil.build]
description = "Build"
language = "shell"
silent = true
run = "west build -b {} ."
[sigil.pristine]
description = "Pristine build"
language = "shell"
silent = true
run = "west build -p always -b {} ."
[sigil.flash]
description = "Flash"
language = "shell"
silent = true
run = "west flash --runner {}"
[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = "rm -rf build compile_commands.json"
"#,
            board, board, flash_runner
        );
        // Add recover target only for nRF52840-DK
        if board.contains("nrf52840dk") {
            grimoire.push_str(
                r#"
[sigil.recover]
description = "Mass erase Nordic chip (bypass APPROTECT)"
language = "shell"
silent = false
run = '''
/home/vaishnav/zephyr-sdk-1.0.1/hosttools/sysroots/x86_64-pokysdk-linux/usr/bin/openocd \
    -s /home/vaishnav/zephyr-sdk-1.0.1/hosttools/sysroots/x86_64-pokysdk-linux/usr/share/openocd/scripts \
    -c 'source [find interface/jlink.cfg]' \
    -c 'transport select swd' \
    -c 'source [find target/nrf52.cfg]' \
    -c 'init' -c 'nrf52_recover' -c 'exit'
'''
"#,
            );
        }
        write_file(&format!("{}/Grimoire.toml", project_name), &grimoire);
    }
    // -------------------------------------------------
    // Extra steps from the original bash version
    // -------------------------------------------------
    println!("🔨 Running initial pristine build to generate Devicetree headers...");
    if Command::new("west").arg("--version").output().is_err() {
        println!("⚠️  'west' command not found! Make sure your Zephyr Python venv is active.");
        println!("Project files created, but skipping automatic build and symlinking.");
    } else {
        let status = Command::new("west")
            .args([
                "build",
                "-p",
                "always",
                "-b",
                &board,
                "-d",
                &format!("{}/build", project_name),
                &project_name,
            ])
            .status()
            .expect("Failed to run west build");
        if status.success() {
            println!("🔗 Symlinking compile_commands.json for Neovim/clangd...");
            let compile_commands = format!("{}/build/compile_commands.json", project_name);
            if Path::new(&compile_commands).exists() {
                let _ = std::os::unix::fs::symlink(
                    "build/compile_commands.json",
                    format!("{}/compile_commands.json", project_name),
                );
                // Create .gitignore
                write_file(
                    &format!("{}/.gitignore", project_name),
                    "build/\ncompile_commands.json\n",
                );
            } else {
                println!("⚠️  compile_commands.json not found in build directory.");
            }
        } else {
            println!("⚠️  Initial west build failed. You may need to run it manually.");
        }
    }
    println!("✅ Zephyr project '{}' created for '{}'!", project_name, board);
}

// ==================== Arduino ====================
fn create_arduino() {
    println!("♾️ Creating Arduino project...");
    if Command::new("arduino-cli").arg("version").output().is_err() {
        eprintln!("Error: arduino-cli not found. Please install it first.");
        exit(1);
    }
    let project_name = prompt_project_name();
    let fqbn = Text::new("Enter board FQBN (e.g. arduino:avr:uno):")
        .prompt()
        .unwrap_or_else(|_| {
            println!("Aborted.");
            exit(0);
        });
    let status = Command::new("arduino-cli")
        .args(["sketch", "new", &project_name])
        .status()
        .expect("Failed to create sketch");
    if !status.success() {
        exit(1);
    }
    env::set_current_dir(&project_name).ok();
    println!("📎 Attaching board {} to generate sketch.yaml...", fqbn);
    let _ = Command::new("arduino-cli")
        .args(["board", "attach", "-b", &fqbn])
        .status();
    write_file(
        "Grimoire.toml",
        r#"version = "1"
[sigil.build]
description = "Compile the sketch"
language = "shell"
silent = true
run = "arduino-cli compile"
[sigil.upload]
description = "Upload (pass port as argument)"
language = "shell"
silent = true
run = "arduino-cli upload -p {{port}}"
[sigil.upload.args.port]
type = "text"
default = "/dev/ttyUSB0"
[sigil.monitor]
description = "Serial monitor"
language = "shell"
silent = false
run = "arduino-cli monitor -p {{port}}"
[sigil.monitor.args.port]
type = "text"
default = "/dev/ttyUSB0"
[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = "rm -rf build"
"#,
    );
    println!("✅ Arduino project '{}' created for '{}'!", project_name, fqbn);
}

// ==================== Ada ====================
fn create_ada() {
    println!("⚙️ Creating Ada SPARK project...");
    if Command::new("alr").arg("--version").output().is_err() {
        eprintln!("Error: Alire (alr) not found. Please ensure it is in your PATH.");
        exit(1);
    }
    let project_name = prompt_project_name();
    println!("📦 Initializing Alire project...");
    let status = Command::new("alr")
        .args(["init", "--bin", &project_name])
        .status()
        .expect("Failed to run alr init");
    if !status.success() {
        exit(1);
    }
    env::set_current_dir(&project_name).ok();
    println!("➕ Adding gnatprove dependency...");
    let _ = Command::new("alr").args(["with", "gnatprove"]).status();
    let adb_file = format!("src/{}.adb", project_name.to_lowercase());
    write_file(
        &adb_file,
        &format!(
            r#"with Ada.Text_IO; use Ada.Text_IO;
procedure {} is
begin
end {};
"#,
            project_name, project_name
        ),
    );
    write_file(
        ".gitignore",
        r#"# Compiled Objects and Executables
/obj/
/bin/
# Alire-specific configuration and cache
/alire/
/config/
alire.toml.prev
alire.lock.prev
# SPARK Verification Artifacts
gnatprove/
*.log
*.spark
"#,
    );
    write_file(
        "Grimoire.toml",
        r#"version = "1"
[sigil.build]
description = "Build with Alire"
language = "shell"
silent = true
run = "alr build"
[sigil.run]
description = "Run"
language = "shell"
silent = true
run = "alr run"
[sigil.prove]
description = "Run gnatprove"
language = "shell"
silent = false
run = "alr gnatprove"
[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = '''
alr clean
rm -rf obj/ bin/
'''
"#,
    );
    println!("✅ Ada SPARK project '{}' created!", project_name);
}

// ==================== D-simple ====================
fn create_d_simple() {
    println!("🇩 Creating D (simple) project...");
    let project_name = prompt_project_name();
    let description = Text::new("Enter project description:")
        .prompt()
        .unwrap_or_else(|_| "A D project".to_string());
    create_dir_and_cd(&project_name);
    let content = format!(
        r#"#!/usr/bin/env dub
/+ dub.sdl:
      name "{}"
      description "{}"
 +/
import std.stdio : writeln;
void main() {{
    writeln("Hello from D!");
}}
"#,
        project_name, description
    );
    write_file(&format!("{}.d", project_name), &content);
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(format!("{}.d", project_name))
            .unwrap()
            .permissions();
        perms.set_mode(0o755);
        fs::set_permissions(format!("{}.d", project_name), perms).ok();
    }
    println!("✅ D-simple project '{}' created!", project_name);
    println!("🚀 You can run it directly using: ./{}.d", project_name);
}

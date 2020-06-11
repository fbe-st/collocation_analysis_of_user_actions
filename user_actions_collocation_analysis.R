library(tidyverse)
library(quanteda)
library(visNetwork)


##### SET UP PARALLEL BACKEND ----
quanteda_options(threads = (RcppParallel::defaultNumThreads() - 1))
cat(paste0("Quanteda using ", quanteda_options("threads"), " parallel processing threads.\nLeaving 1 available for you to browse for cat pictures while you wait..."))


##### LOAD DATA ----
rnd_events_sessions <- readRDS(file = "wip/rnd_events_sessions.RDS") %>% 
  filter(! event_name %in% c("user_create_time", "last_updated", "last_visit")) %>% 
  ungroup() %>% 
  arrange(desc(client_name), user_id, session_id)

# IMPORTANT: The wip file was added to .gitignore
# The object "rnd_events_sessions" hast the following structure:
# > glimpse(rnd_events_sessions)
# Rows: 437,007
# Columns: 10
# $ user_id                  <chr> "030b8691-390c-4665-946e-8495409c6000", "030b8691-390c-4665-946e-8495409c6000"...
# $ client_name              <chr> "weare", "weare", "weare", "weare", "weare", "weare", "weare", "weare", "weare...
# $ event_name               <chr> "first_visit", "Your welcome to Sharktower", "Secret #1", "completed_at_change...
# $ event_timestamp          <dttm> 2020-03-02 12:16:17, 2020-03-02 12:16:34, 2020-03-02 12:16:39, 2020-03-02 13:...
# $ time_since_last          <dbl> 1114565, 17, 5, 4848, 8130, 225, 0, 5658, 67539, 3743, 494, 301, 82257, 3688, ...
# $ new_session              <lgl> TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, ...
# $ session_id               <int> 2, 2, 2, 3, 4, 4, 4, 5, 6, 7, 7, 7, 8, 9, 9, 9, 10, 11, 12, 12, 12, 12, 1, 2, ...
# $ event_object_id          <chr> "030b8691-390c-4665-946e-8495409c6000", "VxlX6Wy5IEYvtiadRGaKOAjVgOE", "rBW82Y...
# $ event_object_description <chr> "user", "guide", "guide", "task", "task", "task", "task", "task", "guide", "ta...
# $ source                   <chr> "pendo-visitors", "pendo-events", "pendo-events", "core-v2_tasks_hist", "core-...


##### CREATE SEQUENCE OF EVENTS:
rnd_events_seqs <- rnd_events_sessions %>% 
  mutate(event_name = str_replace_all(event_name, pattern = "[#!\\?/&;:]", replacement = "")) %>% 
  mutate(event_name = str_replace_all(event_name, pattern = " ", replacement = "_")) %>% 
  mutate(event_name_temp = paste0(event_object_description, "__", event_name)) %>% 
  group_by(user_id, session_id) %>% 
  mutate(event_seqs = str_c(event_name_temp, collapse = " ")) %>% 
  ungroup() %>% 
  distinct(user_id, session_id, .keep_all = TRUE) %>% 
  mutate(session_uuid = paste0(user_id, "_", session_id)) %>% 
  select(session_uuid, user_id, session_id, client_name, event_timestamp, event_seqs)


##### TOKENISE SEQUENCE OF EVENTS:
corpus_obj <- corpus(x = rnd_events_seqs, text_field = "event_seqs", docid_field = "session_uuid")
tokens_obj <- tokens_tolower(tokens(x = corpus_obj,
                                    split_hyphens = FALSE,
                                    remove_punct = FALSE,
                                    remove_numbers = FALSE,
                                    remove_symbols = FALSE))
print(paste0("Number of tokens after initial tokenization: ", length(unique(types(tokens_obj))))) # 207
saveRDS(tokens_obj, file = "wip/tokens_obj_collocations_seq_analysis.RDS")


##### TRAIN COLLOCATIONS:
mwe_obj <- textstat_collocations(x = tokens_obj, size = c(2:15), min_count = 50)
# size 2:15 min_count 50 -> 17.32 sec elapsed 


##### RESHAPE COLLOCATIONS OBJECT:
mwe_analysis <- mwe_obj %>%
  mutate(collocation = str_replace_all(string = collocation, pattern = " ", replacement = " -> ")) %>% 
  mutate(unique_events = collocation %>% 
           str_split(pattern = " -> ") %>% 
           lapply(., function(x) unique(x)) %>% 
           lapply(., function(x) length(x)) %>% 
           unlist()) %>% 
  arrange(desc(length), desc(count), count_nested, unique_events)


##### BUILD EDGE LIST:
min_freq <- 200
temp_mwe_analysis <- mwe_analysis %>% 
  filter(count > min_freq)

events_edge_list <- tibble()
for (i in 1:length(temp_mwe_analysis$collocation)) {
  temp_rule <- temp_mwe_analysis$collocation[i]
  temp_steps <- str_split(temp_rule, pattern = " -> ") %>% 
    unlist()
  temp_freq <- temp_mwe_analysis$count[i]
  temp_nested <- temp_mwe_analysis$count_nested[i]
  temp_length <- temp_mwe_analysis$length[i]
  temp_lambda <- temp_mwe_analysis$lambda[i]
  temp_ztest <- temp_mwe_analysis$z[i]
  temp_unique <- temp_mwe_analysis$unique_events[i]
  for (j in 1:length(temp_steps) - 1) {
    temp_from <- temp_steps[j]
    temp_to <- temp_steps[j + 1]
    temp_edge <- tibble(from = temp_from, 
                        to = temp_to, 
                        freq = temp_freq,
                        nested = temp_nested,
                        length = temp_length,
                        lambda = temp_lambda,
                        ztest = temp_ztest,
                        unique = temp_unique)
    events_edge_list <- bind_rows(events_edge_list, temp_edge)
  }
}
# ~ 20 sec elapsed -> Full mwe_obj


##### BUILD GRAPH:
g <- igraph::graph_from_data_frame(events_edge_list, directed = TRUE)
deg_in <- igraph::degree(g, mode = "in")
deg_out <- igraph::degree(g, mode = "out")

vis_nodes <- data.frame(id=igraph::V(g)$name, label=igraph::V(g)$name, stringsAsFactors = FALSE)
vis_nodes$size <- if_else(igraph::V(g)$name %in% unique(events_edge_list$from), 30, 10) + log(deg_out)
vis_nodes$color.background <- heat.colors(length(levels(factor(deg_out))), alpha = 0.75, rev = TRUE)[factor(deg_out)]
vis_nodes$color.border <- "#E6E6E6"
vis_nodes$color.highlight.background <- "orange"
vis_nodes$color.highlight.border <- "darkred"

vis_edges <- data.frame(from=events_edge_list$from, to=events_edge_list$to)
vis_edges$arrows <- "to"


##### SAVE NODE & EDGE LIST:
saveRDS(vis_nodes, file = "wip/vis_nodes_collocation_collocations_seq_analysis.RDS")
saveRDS(vis_edges, file = "wip/vis_edges_collocation_collocations_seq_analysis.RDS")


##### PLOT GRAPH:
visNetwork(vis_nodes, vis_edges, height = "800px", width = "1600px", 
           main = paste0("User Action Sequences")) %>%
  visIgraphLayout() %>%
  visEdges(smooth = FALSE) %>%
  visExport() %>%
  visOptions(highlightNearest = TRUE,
             nodesIdSelection = list(enabled = TRUE))
